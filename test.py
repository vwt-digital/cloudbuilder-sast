import os
import subprocess
import unittest


class TestSastScan(unittest.TestCase):

    def testPositive(self):
        print("############### POSITIVE TESTS ###############")
        for file in os.listdir('tests/positive'):
            self.assertEqual(subprocess.call('./docker-sast.sh'
                                             ' --type python'
                                             ' --type typescript'
                                             ' --target tests/positive/' + file, shell=True), 0)

    def testNegative(self):
        print("############### NEGATIVE TESTS ###############")
        for file in os.listdir('tests/negative'):
            self.assertEqual(subprocess.call('./docker-sast.sh'
                                             ' --type python'
                                             ' --type typescript'
                                             ' --target tests/negative/' + file, shell=True), 1)


if __name__ == '__main__':
    unittest.main()
