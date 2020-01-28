part of "network.dart";

class Neuron {
  static Random r = Random();
  List<double> weights;
  List<double> weightAdj;
  double gamma;
  double error;
  List<double> inputs;
  double output;
  NormalizationFunction normalizationFunction;

  Neuron(int inputCount, {this.normalizationFunction}) {
    this.weights = List<double>();
    this.weightAdj = List<double>();
    this.inputs = List<double>();

    // Initialize weights and empty weight adjustments
    for (int j = 0; j < inputCount; j++) {
      weights.add(2 * r.nextDouble() - 1);
      weightAdj.add(0.0);
    }
  }

  double sigmoid(double x) => 1.0 / (1.0 + exp(-x));
  double sigmoidDerivative(double x) => sigmoid(x) * (1.0 - sigmoid(x));
  double sigmoidishDerivative(double x) => x * (1.0 - x);

  double tanh(double x) => (exp(x) - exp(-x)) / (exp(x) + exp(-x));
  double tanHDerivative(double x) => 1.0 - (x * x);

  double relu(double x) => x > 0.0 ? x : 0.0;
  double reluDerivative(double x) => x > 0.0 ? 1.0 : 0.0;

  double leakyRelu(double x) => x > 0.0 ? x : 0.1 * x;
  double leakyReluDerivative(double x) => x > 0.0 ? 1.0 : 0.1;

  double softplus(double x) => log(1 + exp(x));
  double softplusDerivative(double x) => 1.0 / (1.0 + exp(-x));

  double normalize(double x) {
    switch (Network.normalizationFunction) {
      case NormalizationFunction.relu:
        return relu(x);
      case NormalizationFunction.leakyRelu:
        return leakyRelu(x);
      case NormalizationFunction.sigmoid:
        return sigmoid(x);
      case NormalizationFunction.sigmoidish:
        return sigmoid(x);
      case NormalizationFunction.tanh:
        return tanh(x);
      case NormalizationFunction.softplus:
        return softplus(x);
      default:
        return sigmoid(x);
    }
  }

  double normalizeDerivative(double x) {
    switch (Network.normalizationFunction) {
      case NormalizationFunction.relu:
        return reluDerivative(x);
      case NormalizationFunction.leakyRelu:
        return leakyReluDerivative(x);
      case NormalizationFunction.sigmoid:
        return sigmoidDerivative(x);
      case NormalizationFunction.tanh:
        return tanHDerivative(x);
      case NormalizationFunction.softplus:
        return softplusDerivative(x);
      case NormalizationFunction.sigmoidish:
        return sigmoidishDerivative(x);
      default:
        return sigmoidDerivative(x);
    }
  }

  void changeNormalization(NormalizationFunction n) => this.normalizationFunction = n;

  double forwardPropagation(List<double> input) {
    this.inputs = input;
    output = 0;
    for (int i = 0; i < inputs.length; i++) {
      output += inputs[i] * weights[i];
    }
    output = normalize(output);
    return output;
  }

  void backPropagationOutput(double expected) {
    error = expected - output;
    gamma = error * normalizeDerivative(output);
    // For each input calculate the new corresponding weight
    for (int i = 0; i < inputs.length; i++) {
      weightAdj[i] = gamma * inputs[i];
    }
  }

  void backPropagationHidden(List<double> gammaForward, List<double> weightsForward) {
    gamma = 0;
    // Pulling each weight corresponding to this neuron in the layer
    for (int j = 0; j < gammaForward.length; j++) {
      gamma += gammaForward[j] * weightsForward[j];
    }
    gamma *= normalizeDerivative(output);
    for (int i = 0; i < weightAdj.length; i++) {
      weightAdj[i] = gamma * inputs[i];
    }
  }
}

enum NormalizationFunction {
  sigmoid,
  sigmoidish,
  tanh,
  relu,
  softplus,
  leakyRelu,
}
