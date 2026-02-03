from pydantic import BaseModel
from typing import Literal


class MedicationCreate(BaseModel):
    name: str
    dose: str
    time: str


class MedicationOut(MedicationCreate):
    id: int
    name: str
    dose: str
    time: str
    user_id: int

    class Config:
        from_attributes = True


class RegisterRequest(BaseModel):
    username: str
    password: str
    role: Literal["patient", "doctor"] = "patient"


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
