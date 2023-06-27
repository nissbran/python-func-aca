FROM python:3.11.0-slim as build
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
	build-essential gcc 

WORKDIR /usr/app
RUN python -m venv /usr/app/venv
ENV PATH="/usr/app/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install -r requirements.txt

FROM python:3.11.0-slim as app

RUN groupadd -g 999 python && \
    useradd -r -u 999 -g python python

RUN mkdir /usr/app && chown python:python /usr/app
WORKDIR /usr/app

COPY --chown=python:python --from=build /usr/app/venv ./venv
COPY --chown=python:python . .

USER 999

ENV PATH="/usr/app/venv/bin:$PATH"

CMD [ "gunicorn", "--bind", "0.0.0.0:5000", "subscriber:app" ]
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD curl -f http://localhost:5000/health