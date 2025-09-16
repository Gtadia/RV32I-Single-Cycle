#!/bin/bash

rm -f ece3058_lab1_submission.tar.gz
tar -czvf ece3058_lab1_submission.tar.gz *.sv include/core_pkg.sv
echo
echo 'Submission tarball written to ece3058_lab1_submission.tar.gz'
echo 'Please decompress it yourself and make sure it looks right!'
echo 'Then submit it to Gradescope'