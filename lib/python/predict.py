import joblib
import numpy as np
from pathlib import Path

# Functions that load pickle

model_path = Path('.') / 'data' / 'model.pkl'

def load_model(model_path):
	model = joblib.load(open(model_path, 'rb'))
	return model


# Function that predicts
def predict(path, input):
	model = load_model(path)
	pred  = model.predict(np.array([input]))
	return pred