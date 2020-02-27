# This file should fail the Bandit check
import subprocess as subp


class TestClass:
    def __init__(self, eval_value):
        self.eval_value = eval_value

    def evaluate(self):
        return eval(self.eval_value)

    subp.Popen('tar ./*/*')
