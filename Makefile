.PHONY: install up down migrate test lint fmt types security check clean changelog bump

install:
	pip install -e ".[dev]"
	pre-commit install --hook-type pre-commit --hook-type commit-msg --hook-type pre-push

up:
	docker compose up -d postgres

down:
	docker compose down -v

migrate:
	alembic upgrade head

test:
	pytest -n auto

lint:
	ruff check .

fmt:
	ruff format .

types:
	mypy src

security:
	bandit -c pyproject.toml -r src
	pip-audit --strict --desc on
	detect-secrets scan --baseline .secrets.baseline

check: lint fmt types security test
	@echo "All quality gates passed."

changelog:
	cz changelog

bump:
	cz bump --changelog

clean:
	rm -rf .pytest_cache .mypy_cache .ruff_cache htmlcov .coverage coverage.xml dist build
	find . -type d -name __pycache__ -prune -exec rm -rf {} +