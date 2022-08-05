from flask import Flask
app = Flask(__name__)

@app.route("/teste")
def index():
	return 'Olá Mundo!'

if __name__ == "__main__":
	app.run()