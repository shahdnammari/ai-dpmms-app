from fastapi import FastAPI, Depends, Request, Form, HTTPException, Query
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from models import User, Medication
from auth import hash_password, verify_password
from starlette.middleware.sessions import SessionMiddleware
from sqlalchemy.orm import Session

from db import Base, engine, SessionLocal
from schemas import MedicationCreate, MedicationOut

app = FastAPI(title="AI-DPMMS Local API")
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")


app.add_middleware(
    SessionMiddleware,
    secret_key="CHANGE_ME_TO_A_RANDOM_SECRET_KEY",
    same_site="lax",
    https_only=False
)

# Create tables
Base.metadata.create_all(bind=engine)


def get_current_user_id(request: Request) -> int | None:
    return request.session.get("user_id")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/api/health")
def health():
    return {"status": "ok", "message": "AI-DPMMS local API is running"}


@app.get("/medications", response_model=list[MedicationOut])
def list_medications(user_id: int = Query(...), db: Session = Depends(get_db)):
    return (
        db.query(Medication)
        .filter(Medication.user_id == user_id)
        .order_by(Medication.id.desc())
        .all()
    )


@app.post("/medications", response_model=MedicationOut)
def create_medication(payload: MedicationCreate,
                      db: Session = Depends(get_db)):
    med = Medication(
        name=payload.name,
        dose=payload.dose,
        time=payload.time,
        user_id=payload.user_id
        )
    db.add(med)
    db.commit()
    db.refresh(med)
    return med


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "active_page": "home page"})


@app.get("/register", response_class=HTMLResponse)
def register_page(request: Request):
    return templates.TemplateResponse(
        "register.html",
        {"request": request, "active_page": "register page"})


@app.post("/register", response_class=HTMLResponse)
def register_post(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    existing = db.query(User).filter(User.username == username).first()
    if existing:
        return templates.TemplateResponse(
            "register.html",
            {
                "request": request,
                "error": "שם משתמש כבר קיים"
            }
        )

    user = User(
        username=username,
        password_hash=hash_password(password)
    )
    db.add(user)
    db.commit()

    return RedirectResponse(url="/login", status_code=303)


@app.get("/login", response_class=HTMLResponse)
def login(request: Request):
    return templates.TemplateResponse(
        "login.html",
        {"request": request, "active_page": "login page"})


@app.get("/logout")
def logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/login", status_code=303)


@app.get("/medications-ui", response_class=HTMLResponse)
def medications_ui(
    request: Request,
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    if not user_id:
        return RedirectResponse(url="/login", status_code=303)

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        request.session.clear()
        return RedirectResponse(url="/login", status_code=303)

    meds = (
        db.query(Medication)
        .filter(Medication.user_id == user_id)
        .order_by(Medication.id.desc())
        .all()
    )

    return templates.TemplateResponse(
        "medications.html",
        {
            "request": request,
            "active_page": "medications page",
            "medications": meds,
            "username": user.username
        }
    )


@app.post("/medications-ui")
def add_medication_ui(
    request: Request,
    name: str = Form(...),
    dose: str = Form(...),
    time: str = Form(...),
    db: Session = Depends(get_db)
):
    user_id = get_current_user_id(request)
    if not user_id:
        raise RedirectResponse(url="/login", status_code=303)

    med = Medication(name=name, dose=dose, time=time, user_id=user_id)
    db.add(med)
    db.commit()

    return RedirectResponse(
        url="/medications-ui",
        status_code=303
        )


@app.get("/home", response_class=HTMLResponse)
def home_page(request: Request):
    return templates.TemplateResponse("home.html", {"request": request})


@app.post("/api/register")
def register(username: str = Form(...),
             password: str = Form(...),
             db: Session = Depends(get_db)
             ):
    existing = db.query(User).filter(User.username == username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")

    user = User(username=username, password_hash=hash_password(password))
    db.add(user)
    db.commit()
    return {"registered": True}


@app.post("/login")
def login_post(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    request.session["user_id"] = user.id

    return RedirectResponse(
        url="/medications-ui",
        status_code=303
    )


@app.post("/medications-ui/{med_id}/delete")
def delete_med_ui(
    reqquest: Request,
    med_id: int,
    db: Session = Depends(get_db)
):

    user_id = get_current_user_id(reqquest)
    if not user_id:
        return RedirectResponse(url="/login", status_code=303)

    med = db.query(Medication).filter(
        Medication.id == med_id,
        Medication.user_id == user_id
    ).first()

    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    db.delete(med)
    db.commit()

    return RedirectResponse(
        url="/medications-ui",
        status_code=303
    )


@app.get("/medications-ui/{med_id}/edit", response_class=HTMLResponse)
def edit_med_page(
    request: Request,
    med_id: int,
    db: Session = Depends(get_db)
):

    user_id = get_current_user_id(request)
    if not user_id:
        return RedirectResponse(url="/login", status_code=303)

    med = db.query(Medication).filter(
        Medication.id == med_id,
        Medication.user_id == user_id
    ).first()

    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    return templates.TemplateResponse(
        "med_edit.html",
        {"request": request,
         "active_page": "edit medication page",
         "med": med}
    )


@app.post("/medications-ui/{med_id}/edit")
def edit_med_save(
    request: Request,
    med_id: int,
    name: str = Form(...),
    dose: str = Form(...),
    time: str = Form(...),
    db: Session = Depends(get_db)
):

    user_id = get_current_user_id(request)
    if not user_id:
        return RedirectResponse(url="/login", status_code=303)

    med = db.query(Medication).filter(
        Medication.id == med_id,
        Medication.user_id == user_id
    ).first()

    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    med.name = name
    med.dose = dose
    med.time = time
    db.commit()

    return RedirectResponse(
        url="/medications-ui",
        status_code=303
    )
