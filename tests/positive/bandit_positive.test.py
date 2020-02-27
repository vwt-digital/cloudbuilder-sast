# This file should fail the Bandit check
import ast
import subprocess as subp  # nosec


class TestClass:
    def __init__(self, eval_value):
        self.eval_value = eval_value

    def evaluate(self):
        return ast.literal_eval(self.eval_value)

    subp.Popen('tar ./*/*')  # nosec
