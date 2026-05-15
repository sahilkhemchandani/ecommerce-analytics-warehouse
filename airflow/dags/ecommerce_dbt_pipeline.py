"""
Airflow DAG: ecommerce_dbt_pipeline
Orchestrates dbt runs for the Snowflake E-Commerce DWH.

Schedule: Daily at 02:00 UTC
Tasks:
    1. dbt deps         — install packages
    2. dbt source test  — validate raw data before transforming
    3. dbt run staging  — run staging views
    4. dbt run marts    — run mart tables (incremental for sales_daily)
    5. dbt test marts   — run all mart tests
    6. notify_success   — log completion

Prerequisites:
    pip install apache-airflow apache-airflow-providers-docker
    or run with BashOperator if dbt is installed on Airflow worker.

Set Airflow Variables:
    - dbt_project_dir: /opt/airflow/dbt/ecomm_dw
    - dbt_profiles_dir: /opt/airflow/dbt

Set Airflow Connections (for Snowflake alerts — optional):
    - slack_default (if using Slack notifications)
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.models import Variable
from airflow.utils.trigger_rule import TriggerRule
import logging

# ─── CONFIG ───────────────────────────────────────────────────────────────────
DBT_PROJECT_DIR  = Variable.get("dbt_project_dir",  default_var="/opt/airflow/dbt/ecomm_dw")
DBT_PROFILES_DIR = Variable.get("dbt_profiles_dir", default_var="/opt/airflow/dbt")
DBT_TARGET       = Variable.get("dbt_target",       default_var="prod")

DBT_CMD = (
    f"cd {DBT_PROJECT_DIR} && "
    f"dbt {{cmd}} --profiles-dir {DBT_PROFILES_DIR} --target {DBT_TARGET}"
)

DEFAULT_ARGS = {
    "owner":            "data_engineering",
    "depends_on_past":  False,
    "email_on_failure": False,
    "email_on_retry":   False,
    "retries":          1,
    "retry_delay":      timedelta(minutes=5),
}


# ─── NOTIFICATION CALLBACK ────────────────────────────────────────────────────
def on_failure_callback(context):
    task_id    = context["task_instance"].task_id
    dag_id     = context["dag"].dag_id
    exec_date  = context["execution_date"]
    log_url    = context["task_instance"].log_url
    logging.error(
        f"TASK FAILED | DAG: {dag_id} | Task: {task_id} | "
        f"Exec: {exec_date} | Logs: {log_url}"
    )
    # Extend here: post to Slack, PagerDuty, email, etc.


def log_pipeline_success(**context):
    run_id = context["run_id"]
    logging.info(f"✓ ecommerce_dbt_pipeline completed successfully | run_id={run_id}")


# ─── DAG DEFINITION ───────────────────────────────────────────────────────────
with DAG(
    dag_id          = "ecommerce_dbt_pipeline",
    default_args    = DEFAULT_ARGS,
    description     = "Daily dbt run for Snowflake E-Commerce DWH",
    schedule_interval = "0 2 * * *",          # 02:00 UTC daily
    start_date      = datetime(2024, 1, 1),
    catchup         = False,
    max_active_runs = 1,
    tags            = ["dbt", "snowflake", "ecommerce", "data-warehouse"],
    on_failure_callback = on_failure_callback,
) as dag:

    # ── 1. Install dbt packages ───────────────────────────────────────────────
    dbt_deps = BashOperator(
        task_id     = "dbt_deps",
        bash_command= DBT_CMD.format(cmd="deps"),
    )

    # ── 2. Validate raw source data ───────────────────────────────────────────
    dbt_source_test = BashOperator(
        task_id     = "dbt_source_test",
        bash_command= DBT_CMD.format(cmd="test --select source:raw"),
    )

    # ── 3. Run staging layer ──────────────────────────────────────────────────
    dbt_run_staging = BashOperator(
        task_id     = "dbt_run_staging",
        bash_command= DBT_CMD.format(cmd="run --select staging"),
    )

    # ── 4. Run mart layer ─────────────────────────────────────────────────────
    dbt_run_marts = BashOperator(
        task_id     = "dbt_run_marts",
        bash_command= DBT_CMD.format(cmd="run --select marts"),
    )

    # ── 5. Test marts ─────────────────────────────────────────────────────────
    dbt_test_marts = BashOperator(
        task_id     = "dbt_test_marts",
        bash_command= DBT_CMD.format(cmd="test --select marts"),
    )

    # ── 6. Generate docs (optional, weekly) ──────────────────────────────────
    dbt_docs_generate = BashOperator(
        task_id     = "dbt_docs_generate",
        bash_command= DBT_CMD.format(cmd="docs generate"),
    )

    # ── 7. Log success ────────────────────────────────────────────────────────
    notify_success = PythonOperator(
        task_id     = "notify_success",
        python_callable = log_pipeline_success,
        trigger_rule = TriggerRule.ALL_SUCCESS,
    )

    # ── DEPENDENCY CHAIN ─────────────────────────────────────────────────────
    (
        dbt_deps
        >> dbt_source_test
        >> dbt_run_staging
        >> dbt_run_marts
        >> dbt_test_marts
        >> dbt_docs_generate
        >> notify_success
    )
