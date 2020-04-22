include Makefile.inc

Makefile.inc AddOne.bsv send_number.cpp: add1_single_threaded.lit
	lit -t add1_single_threaded.lit
add1_single_threaded.html: add1_single_threaded.lit
	lit -w add1_single_threaded.lit
