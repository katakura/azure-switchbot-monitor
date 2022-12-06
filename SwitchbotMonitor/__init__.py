import datetime
import logging
import os
import time
import hashlib
import hmac
import base64
import requests
import json
import azure.functions as func
import azure.monitor.ingestion as azlog
import azure.core
from azure.identity import DefaultAzureCredential

sb_base_url = 'https://api.switch-bot.com/v1.1/'

# make signature for SwitchBot API 1.1
def sb_make_sign(token: str, secret: str):
    nonce = ''
    t = int(round(time.time() * 1000))
    string_to_sign = bytes(f'{token}{t}{nonce}', 'utf-8')
    secret = bytes(secret, 'utf-8')
    sign = base64.b64encode(
        hmac.new(secret, msg=string_to_sign, digestmod=hashlib.sha256).digest())
    return sign, str(t), nonce

# make request header for SwitchBot API 1.1
def sb_make_request_header(token: str, secret: str) -> dict:
    sign, t, nonce = sb_make_sign(token, secret)
    headers = {
        "Authorization": token,
        "sign": sign,
        "t": str(t),
        "nonce": nonce
    }
    return headers

# GET request for SwitchBot API 1.1
def get_switchbot(url: str, headers):
    try:
        res = requests.get(url, headers=headers)
        res.raise_for_status()

    except requests.exceptions.RequestException as e:
        logging.error('response error:', e)

    return json.loads(res.text)

# main routine
def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()
    logging.info('Python timer trigger function ran at %s', utc_timestamp)

    if mytimer.past_due:
        logging.info('The timer is past due!')

    # azure log analytics
    token_credential = DefaultAzureCredential()
    log = azlog.LogsIngestionClient(
        os.environ['AZURE_MONITOR_ENDPOINT'], token_credential)
    rule_id = os.environ['AZURE_MONITOR_IMMUTABLEID']
    stream_name = os.environ['AZURE_MONITOR_STREAMNAME']

    # SWITCHBOT
    token = os.environ['SWITCHBOT_TOKEN']
    secret = os.environ['SWITCHBOT_SECRET']
    headers = sb_make_request_header(token, secret)
    list = get_switchbot(sb_base_url + '/devices', headers)

    # get device list
    log_body = []
    for row in list['body']['deviceList']:
        # only 'Meter'
        if row['deviceType'] == 'Meter':
            status = get_switchbot(sb_base_url + "/devices/" + row['deviceId'] + "/status", headers)
            dt_now = datetime.datetime.now()

            out = {}
            out['body'] = status['body']
            out['TimeGenerated'] = dt_now.isoformat()
            out['deviceName'] = row['deviceName']
            out['deviceId'] = row['deviceId']
            log_body.append(out)

    # upload meter log to Log Analytics
    try:
        log.upload(rule_id=rule_id, stream_name=stream_name, logs=log_body)

    except azure.core.exceptions.HttpResponseError as e:
        logging.error('log injest error', e)
