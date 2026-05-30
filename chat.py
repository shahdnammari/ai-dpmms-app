import os
import json
import logging
import traceback
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from dotenv import load_dotenv

logging.basicConfig(level=logging.INFO)

load_dotenv()

router = APIRouter()

_GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
_MODEL = "llama-3.3-70b-versatile"


class ChatRequest(BaseModel):
    question: str
    medications: list[str] = []
    conditions: list[str] = []
    age: Optional[int] = None
    gender: Optional[str] = None
    adherence_summary: Optional[str] = None


async def _fetch_drug_info(drug_name: str) -> dict:
    search_terms = [
        f'openfda.generic_name:"{drug_name}"',
        f'openfda.brand_name:"{drug_name}"',
    ]
    try:
        async with httpx.AsyncClient(timeout=6.0) as client:
            for term in search_terms:
                resp = await client.get(
                    "https://api.fda.gov/drug/label.json",
                    params={"search": term, "limit": 1},
                )
                if resp.status_code == 200:
                    results = resp.json().get("results", [])
                    if results:
                        r = results[0]
                        warnings = r.get("warnings") or r.get("warnings_and_cautions") or []
                        dosage = r.get("dosage_and_administration") or []
                        return {
                            "name": drug_name,
                            "warnings": warnings[0][:200] if warnings else "No warnings found",
                            "dosage_notes": dosage[0][:100] if dosage else "",
                        }
    except Exception:
        pass
    return {"name": drug_name, "warnings": "No information available", "dosage_notes": ""}


def _build_prompt(req: ChatRequest, drug_infos: list[dict]) -> str:
    age_str = str(req.age) if req.age else "not specified"
    gender_str = req.gender or "not specified"
    conditions_str = ", ".join(req.conditions) if req.conditions else "none specified"
    meds_str = ", ".join(req.medications) if req.medications else "none"
    adherence_str = req.adherence_summary or "no adherence data available"

    drug_info_text = "\n".join(
        f"- {d['name']}: {d['warnings']}"
        for d in drug_infos
    ) or "No drug information available."

    return f"""You are a helpful and empathetic medical assistant. Answer the patient's question clearly and safely.

Patient Profile:
- Age: {age_str}
- Gender: {gender_str}
- Medical Conditions: {conditions_str}
- Current Medications: {meds_str}
- Recent Adherence: {adherence_str}

Drug Information (from FDA):
{drug_info_text}

Patient's Question:
"{req.question}"

Instructions:
- Use simple, friendly language — no medical jargon
- Personalize your answer using the patient's profile above
- Do NOT prescribe medications or specific dosages
- Do NOT diagnose medical conditions
- If there is any health risk, clearly warn the patient and recommend consulting their doctor
- Keep your answer to 2-4 sentences
- If the topic involves any risk or uncertainty, end with: "Please consult your doctor if you have concerns."
"""


@router.post("/chat")
async def chat(request: ChatRequest):
    if not request.question.strip():
        raise HTTPException(status_code=400, detail="Question cannot be empty")

    drug_infos = []
    for med in request.medications:
        if med.strip():
            drug_infos.append(await _fetch_drug_info(med.strip()))

    prompt = _build_prompt(request, drug_infos)

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                _GROQ_URL,
                headers={
                    "Authorization": f"Bearer {_GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 300,
                    "temperature": 0.7,
                },
            )

        if resp.status_code == 200:
            answer = resp.json()["choices"][0]["message"]["content"].strip()
            return {"answer": answer}

        logging.error("Groq error: %s %s", resp.status_code, resp.text)
        raise HTTPException(status_code=500, detail=f"AI error: {resp.text}")

    except HTTPException:
        raise
    except Exception as e:
        logging.error("Groq error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"AI service error: {str(e)}")


# ── AI Alert Analysis ─────────────────────────────────────────────────────────

class AnalyzeRequest(BaseModel):
    patient_name: str
    medications: list[str] = []
    conditions: list[str] = []
    total_doses: int = 0
    taken_doses: int = 0
    missed_doses: int = 0
    consecutive_missed: int = 0


class AnalyzeResponse(BaseModel):
    should_alert: bool
    severity: str   # "critical" | "warning" | "info"
    message: str


def _build_analyze_prompt(req: AnalyzeRequest) -> str:
    adherence_pct = (
        round((req.taken_doses / req.total_doses) * 100)
        if req.total_doses > 0 else 0
    )
    meds = ", ".join(req.medications) if req.medications else "none"
    conditions = ", ".join(req.conditions) if req.conditions else "none"

    return f"""You are a medical monitoring AI. Analyze this patient's medication adherence and decide if the doctor should be alerted.

Patient: {req.patient_name}
Medications: {meds}
Conditions: {conditions}
Last 7 days:
- Total doses: {req.total_doses}
- Taken: {req.taken_doses}
- Missed: {req.missed_doses}
- Adherence: {adherence_pct}%
- Consecutive missed doses: {req.consecutive_missed}

Rules:
- Adherence < 50% OR consecutive missed >= 3 OR (insulin/diabetes medication missed 2+ times) → ALERT with severity "critical"
- Adherence 50–70% OR consecutive missed == 2 → ALERT with severity "warning"
- Adherence > 70% AND consecutive missed <= 1 → NO alert
- If no doses recorded yet (total=0) → NO alert

Respond ONLY in this exact JSON format (no extra text):
{{"should_alert": true/false, "severity": "critical/warning/info", "message": "One clear sentence explaining the concern to the doctor."}}"""


@router.post("/analyze", response_model=AnalyzeResponse)
async def analyze(request: AnalyzeRequest):
    prompt = _build_analyze_prompt(request)

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                _GROQ_URL,
                headers={
                    "Authorization": f"Bearer {_GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": _MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": 120,
                    "temperature": 0.2,
                },
            )

        if resp.status_code != 200:
            logging.error("Groq analyze error: %s %s", resp.status_code, resp.text)
            return AnalyzeResponse(should_alert=False, severity="info", message="")

        content = resp.json()["choices"][0]["message"]["content"].strip()

        # Strip markdown code fences if present
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]

        data = json.loads(content)
        return AnalyzeResponse(
            should_alert=bool(data.get("should_alert", False)),
            severity=str(data.get("severity", "info")),
            message=str(data.get("message", "")),
        )

    except Exception:
        logging.error("Analyze error:\n%s", traceback.format_exc())
        return AnalyzeResponse(should_alert=False, severity="info", message="")
