"""
Application settings and Supabase client dependency.
"""

from typing import Annotated

from fastapi import Depends
from pydantic_settings import BaseSettings
from supabase import Client, create_client


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_key: str = ""  # Must be the service role key for admin ops
    database_url: str = ""
    environment: str = "development"

    # Google OAuth (for Calendar integration)
    google_client_id: str = ""
    google_client_secret: str = ""

    # Gemini LLM
    gemini_api_key: str = ""


settings = Settings()


def get_supabase() -> Client:
    """Create and return a Supabase client."""
    return create_client(settings.supabase_url, settings.supabase_key)


SupabaseDep = Annotated[Client, Depends(get_supabase)]
