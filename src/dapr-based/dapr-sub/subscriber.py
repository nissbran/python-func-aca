import json
import time

import flask
import logging

from flask import request, jsonify
from cloudevents.http import from_http

app = flask.Flask(__name__)

if __name__ != '__main__':
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)


@app.route('/dapr/subscribe', methods=['GET'])
def subscribe():
    subscriptions = [{'pubsubname': 'pubsub',
                      'topic': 'updates',
                      'route': 'handler'}]
    return jsonify(subscriptions)


@app.route('/handler', methods=['POST'])
def event_handler():
    event = from_http(request.headers, request.get_data())
    app.logger.info('Received event with id: {}'.format(event['id']))

    time.sleep(0.5)
    # Do stuff here ------

    return json.dumps({'success': True}), 200, {'ContentType': 'application/json'}


@app.route('/health', methods=['GET'])
def health():
    # Handle here any business logic for ensuring you're application is healthy (DB connections, etc...)
    return "Healthy: OK"


if __name__ == "__main__":
    app.run()
