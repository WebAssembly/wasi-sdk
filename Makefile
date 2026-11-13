HELP2MAN = help2man -N

all:

check: check-guess check-sub

manpages: doc/config.guess.1 doc/config.sub.1

check-guess:
	cd testsuite && bash config-guess.sh && rm uname ldd

check-sub:
	cd testsuite && bash config-sub.sh

shellcheck:
	shellcheck -f gcc config.guess config.sub testsuite/*.sh

.PHONY: sort
sort: testsuite/config-guess.data testsuite/config-sub.data
	for f in $^; do LC_ALL=C sort -u $$f -o $$f; done

doc/%.1: % doc/%.x
	$(HELP2MAN) --include=doc/$<.x --output=$@ ./$<

gen_changelog_start_date = 2020-12-21 12:21
.PHONY: ChangeLog
ChangeLog:
	@rm -f $@.new
	{ ./gitlog-to-changelog --append-dot \
		--since='$(gen_changelog_start_date)' && \
	  echo && echo && echo 'See ChangeLog-old for older changes.'; \
	} > $@.new
	mv -f $@.new $@
