add1_single_threaded: add1_single_threaded.lit
	test -d add1_single_threaded || mkdir add1_single_threaded
	lit -t add1_single_threaded.lit -odir add1_single_threaded
	echo 'include Makefile.inc' > add1_single_threaded/Makefile

docs: add1_single_threaded.lit
	rm -r docs
	lit -w index.lit
	mv _book docs
	mv "docs/Simple incrementer examples_contents.html" docs/index.html
