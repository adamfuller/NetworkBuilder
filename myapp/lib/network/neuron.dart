part of "network.dart";

class Neuron {
  List<double> weights;
  List<double> weightAdj;
  double gamma = 0.0;
  double error = 0.0;
  List<double> inputs;
  double output = 0.0;

  Neuron(int inputCount) {
    this.weights = List<double>();
    this.weightAdj = List<double>();
    this.inputs = List<double>();

    // Initialize weights and empty weight adjustments
    for (int j = 0; j < inputCount; j++) {
      weights.add(2 * Network.r.nextDouble() - 1);
      weightAdj.add(0.0);
    }
  }

  factory Neuron.fromJson(Map<String, dynamic> map) {
    Neuron n = Neuron(0);
    n.weights = map["weights"];
    n.weightAdj = map["weightsAdj"];
    n.inputs = map["inputs"];
    n.error = map["error"];
    n.output = map["output"];
    n.gamma = map["gamma"];
    return n;
  }

  Map<String, dynamic> toJson() {
    var output = {
      "weights": weights.map<double>((n) => n.isNaN ? 1 : n).toList(),
      "weightAdj": weightAdj.map<double>((n) => n.isNaN ? 0 : n).toList(),
      "inputs": inputs.map<double>((n) => n.isNaN ? 1 : n).toList(),
      "error": (error?.isNaN) ?? true ? 0 : error,
      "output": this.output?.isNaN ?? true ? 0 : this.output,
      "gamma": gamma?.isNaN ?? true ? 0 : gamma,
    };
    return output;
  }

  void reset() {
    for (int i = 0; i < weights.length; i++) {
      weights[i] = (2 * Network.r.nextDouble() - 1);
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
    switch (Network.activationFunction) {
      case ActivationFunction.relu:
        return relu(x);
      case ActivationFunction.leakyRelu:
        return leakyRelu(x);
      case ActivationFunction.sigmoid:
        return sigmoid(x);
      case ActivationFunction.sigmoidish:
        return sigmoid(x);
      case ActivationFunction.tanh:
        return tanh(x);
      case ActivationFunction.softplus:
        return softplus(x);
      default:
        return sigmoid(x);
    }
  }

  double normalizeDerivative(double x) {
    switch (Network.activationFunction) {
      case ActivationFunction.relu:
        return reluDerivative(x);
      case ActivationFunction.leakyRelu:
        return leakyReluDerivative(x);
      case ActivationFunction.sigmoid:
        return sigmoidDerivative(x);
      case ActivationFunction.tanh:
        return tanHDerivative(x);
      case ActivationFunction.softplus:
        return softplusDerivative(x);
      case ActivationFunction.sigmoidish:
        return sigmoidishDerivative(x);
      default:
        return sigmoidDerivative(x);
    }
  }

  double forwardPropagation(List<double> input) {
    this.inputs = input;
    output = 0;
    // Adjust if input is too large
    if (input.length >= weights.length) {
      for (int i = weights.length; i < input.length; i++) {
        weights.add((2 * Network.r.nextDouble() - 1));
        weightAdj.add(0.0);
      }
    }
    // Adjust if input is too small
    if (inputs.length < weights.length) {
      weights = weights.take(weights.length - (weights.length - inputs.length)).toList();
      weightAdj = weightAdj.take(weightAdj.length - (weightAdj.length - inputs.length)).toList();
    }
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
      if (weightAdj.length <= i) weightAdj.add(0.0);
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
    for (int i = 0; i < inputs.length; i++) {
      if (weightAdj.length <= i) weightAdj.add(0.0);
      weightAdj[i] = gamma * inputs[i];
    }
  }
}

enum ActivationFunction {
  sigmoid,
  sigmoidish,
  tanh,
  relu,
  softplus,
  leakyRelu,
}
