"""
Celery application definition for NEXUS algorithm engine.
Three queues (sentinel, oracle, phantom) for independent scaling.
Beat schedule runs accuracy evaluation and regime classification.
"""
from celery import Celery
from celery.schedules import crontab
from config import settings

app = Celery(
    "nexus",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=[
        "sentinel.tasks",
        "oracle.tasks",
        "phantom.tasks",
        "accuracy.tasks",
    ],
)

app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,  # one task at a time per worker slot

    # Queue routing
    task_routes={
        "sentinel.tasks.*": {"queue": "sentinel"},
        "oracle.tasks.*": {"queue": "oracle"},
        "phantom.tasks.*": {"queue": "phantom"},
        "accuracy.tasks.*": {"queue": "accuracy"},
    },

    # Beat schedule: periodic tasks
    beat_schedule={
        # Run all three algorithms on all symbols every 30 seconds
        "sentinel-all-symbols": {
            "task": "sentinel.tasks.run_all_symbols",
            "schedule": 30.0,
            "options": {"queue": "sentinel"},
        },
        "oracle-all-symbols": {
            "task": "oracle.tasks.run_all_symbols",
            "schedule": 60.0,
            "options": {"queue": "oracle"},
        },
        "phantom-all-symbols": {
            "task": "phantom.tasks.run_all_symbols",
            "schedule": 120.0,  # ARIMA fitting is slower
            "options": {"queue": "phantom"},
        },
        # Accuracy evaluation: every 5 minutes
        "evaluate-accuracy": {
            "task": "accuracy.tasks.evaluate_pending",
            "schedule": 300.0,
            "options": {"queue": "accuracy"},
        },
        # ARIMA refit: every 30 minutes
        "arima-refit": {
            "task": "phantom.tasks.refit_arima_all",
            "schedule": 1800.0,
            "options": {"queue": "phantom"},
        },
    },
)
