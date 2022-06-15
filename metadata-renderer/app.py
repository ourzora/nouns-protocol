from multiprocessing.sharedctypes import Value
from flask import Flask, request as flask_request, Response
from PIL import Image
from xml.dom import minidom
import requests
from io import BytesIO

app = Flask(__name__)

def try_read_int(input_str):
  try:
    return int(input_str)
  except ValueError:
    return None

def handle_png(images):
  image = None
  for image_path_ipfs in images:
    image_path = image_path_ipfs.replace('ipfs://', 'https://zora-prod.mypinata.cloud/ipfs/')
    response = requests.get(image_path)
    new_image = Image.open(BytesIO(response.content))
    if not image:
      image = new_image
    else:
      # sets alpha layer from png itself
      image.paste(new_image, (0, 0), new_image)

  img_byte_arr = BytesIO()
  image.save(img_byte_arr, format='png')

  # Rewind buffer to get image data
  img_byte_arr.seek(0)

  # TODO: Cache response (can just hash the images array)
  return Response(img_byte_arr, status=200, mimetype='image/png')

def handle_svg(images):
  for image_path_ipfs in images:
    # TODO: Use proper IPFS loader
    image_path = image_path_ipfs.replace('ipfs://', 'https://zora-prod.mypinata.cloud/ipfs/')
    response = requests.get(image_path)
    svg_xml = minidom.parse(BytesIO(response.content))
    images_out += svg_xml.documentElement.toxml('utf-8').decode('utf-8')
    width = int(svg_xml.documentElement.getAttribute('width'))
    height = int(svg_xml.documentElement.getAttribute('height'))
  if (width and height and try_read_int(width) and try_read_int(height)):
    width_height_str = f' width="{width}" height="{height}" '
  # TODO: Cache response (can just hash the images array)
  return Response(f'<svg xmlns="http://www.w3.org/2000/svg" {width_height_str}>{images_out}</svg>', status=200, mimetype='image/svg+xml')

@app.route("/render")
def render():
  images = flask_request.args.getlist('images[]')

  if images[0].endswith('.png'):
    return handle_png(images)
  
  if images[0].endswith('.svg'):
    return handle_svg(images)
  
  return Response("no file", status=500)
