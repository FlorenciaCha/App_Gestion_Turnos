# Acá se levanta la app (app = FastAPI()), se configuran middlewares, y se incluyen los routers.
from fastapi import FastAPI
from app.routers import usuarios, obras_sociales, turnos, profesionales, especialidades
from app.database import Base, engine
from app import firebase, models


Base.metadata.create_all(bind=engine)  # Crea las tablas en la base de datos si no existen

app = FastAPI(title="API Turnos Medicos")

# incluir routers
app.include_router(usuarios.router)
app.include_router(obras_sociales.router)
app.include_router(turnos.router)
app.include_router(profesionales.router)
app.include_router(especialidades.router)
