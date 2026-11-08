from ..database import call_proc_scalar


def crear(codigo, nombre, email, asunto, mensaje):
    return call_proc_scalar(
        "usp_contacto_crear",
        (codigo, nombre, email, asunto, mensaje),
    )
