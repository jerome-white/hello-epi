import os
import logging

lvl = os.environ.get('PYTHONLOGLEVEL', 'WARNING').upper()
fmt = '[ %(asctime)s %(levelname)s %(process)d ] %(message)s'
logging.basicConfig(format=fmt, datefmt="%d %H:%M:%S", level=lvl)
logging.getLogger('matplotlib').setLevel(logging.CRITICAL)
logging.captureWarnings(True)
Logger = logging.getLogger(__name__)
