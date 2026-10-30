from contextlib import asynccontextmanager

from psycopg_pool import ConnectionPool

from .config import settings


pool = ConnectionPool(settings.database_url, min_size=1, max_size=10, open=False)


@asynccontextmanager
async def lifespan_pool(_app):
    pool.open(wait=True)
    try:
        yield
    finally:
        pool.close()
