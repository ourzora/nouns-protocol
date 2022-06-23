from flask import Flask, request as flask_request
from PIL import Image, ImageOps
from requests import request

app = Flask(__name__)

@app.route("/render")
def render():
  query_string = flask_request.query_string.decode()
  print(query_string)
