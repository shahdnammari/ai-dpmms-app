from pydantic import BaseModel


class MedicationCreate(BaseModel):
    name: str
    dose: str
    time: str
    user_id: int


class MedicationOut(MedicationCreate):
    id: int

    class Config:
        from_attributes = True
