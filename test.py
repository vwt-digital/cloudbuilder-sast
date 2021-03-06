import os
import subprocess  # nosec
import unittest


class TestSastScan(unittest.TestCase):

    def testPositive(self):
        print("############### POSITIVE TESTS ###############", flush=True)
        for file in os.listdir('tests/positive'):
            with self.subTest("tests/positive/{}".format(file)):
                self.assertEqual(subprocess.call('docker-sast.sh'
                                                 ' --target tests/positive/' + file, shell=True), 0)  # nosec

    def testNegative(self):
        print("############### NEGATIVE TESTS ###############", flush=True)
        for file in os.listdir('tests/negative'):
            with self.subTest("tests/negative/{}".format(file)):
                self.assertEqual(subprocess.call('docker-sast.sh'
                                                 ' --target tests/negative/' + file, shell=True), 1)  # nosec


if __name__ == '__main__':
    unittest.main()
