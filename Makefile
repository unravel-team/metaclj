.PHONY: check-cljkondo check-tagref check-zprint check repl-enrich repl test test-all

HOME := $(shell echo $$HOME)
HERE := $(shell echo $$PWD)
CLOJURE_SOURCES := $(shell find . -name '**.clj')

.DEFAULT_GOAL := repl

# Set bash instead of sh for the @if [[ conditions,
# and use the usual safety flags:
SHELL = /bin/bash -Eeu

# The Clojure CLI aliases that will be selected for main options for `repl`.
# Feel free to upgrade this, or to override it with an env var named DEPS_MAIN_OPTS.
# Expected format: "-M:alias1:alias2"
DEPS_MAIN_OPTS ?= "-M:dev:test:logs-dev:cider-storm"

# The enrich-classpath version to be injected.
# Feel free to upgrade this.
ENRICH_CLASSPATH_VERSION="1.19.3"

# Create and cache a `clojure` command. deps.edn is mandatory; the others are optional but are taken into account for cache recomputation.
# It's important not to silence with step with @ syntax, so that Enrich progress can be seen as it resolves dependencies.
.enrich-classpath-repl: Makefile deps.edn $(wildcard $(HOME)/.clojure/deps.edn) $(wildcard $(XDG_CONFIG_HOME)/.clojure/deps.edn)
	cd $$(mktemp -d -t enrich-classpath.XXXXXX); clojure -Sforce -Srepro -J-XX:-OmitStackTraceInFastThrow -J-Dclojure.main.report=stderr -Sdeps '{:deps {mx.cider/tools.deps.enrich-classpath {:mvn/version $(ENRICH_CLASSPATH_VERSION)}}}' -M -m cider.enrich-classpath.clojure "clojure" "$(HERE)" "true" $(DEPS_MAIN_OPTS) | grep "^clojure" > $(HERE)/$@

# Launches a repl, falling back to vanilla Clojure repl if something went wrong during classpath calculation.
repl-enrich: .enrich-classpath-repl
	@if grep --silent "^clojure" .enrich-classpath-repl; then \
		echo "Executing: $$(cat .enrich-classpath-repl)" && \
		eval $$(cat .enrich-classpath-repl); \
	else \
		echo "Falling back to Clojure repl... (you can avoid further falling back by removing .enrich-classpath-repl)"; \
		clojure $(DEPS_MAIN_OPTS); \
	fi

.clj-kondo:
	mkdir .clj-kondo

install-kondo-configs: .clj-kondo
	clj-kondo --lint "$$(clojure -A:dev:test:cider:build -Spath)" --copy-configs --skip-lint

check-zprint-config:
	@echo "Checking (HOME)/.zprint.edn..."
	@if [ ! -f "$(HOME)/.zprint.edn" ]; then \
		echo "Error: ~/.zprint.edn not found"; \
		echo "Please create ~/.zprint.edn with the content: {:search-config? true}"; \
		exit 1; \
	fi
	@if ! grep -q "search-config?" "$(HOME)/.zprint.edn"; then \
		echo "Warning: ~/.zprint.edn might not contain required {:search-config? true} setting"; \
		echo "Please ensure this setting is present for proper functionality"; \
		exit 1; \
	fi

.zprint.edn:
	@echo "Creating .zprint.edn..."
	@echo '{:fn-map {"with-context" "with-meta"}, :map {:indent 0}}' > .zprint.edn

.dir-locals.el:
	@echo "Creating .dir-locals.el..."
	@echo ';;; Directory Local Variables         -*- no-byte-compile: t; -*-' > .dir-locals.el
	@echo ';;; For more information see (info "(emacs) Directory Variables")' >> .dir-locals.el
	@echo '((clojure-dart-ts-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojure-jank-ts-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojure-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojure-ts-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojurec-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojurec-ts-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojurescript-mode . ((apheleia-formatter . (zprint))))' >> .dir-locals.el
	@echo ' (clojurescript-ts-mode . ((apheleia-formatter . (zprint)))))' >> .dir-locals.el

install-zprint-config: check-zprint-config .zprint.edn .dir-locals.el
	@echo "zprint configuration files created successfully."

repl:
	clojure $(DEPS_MAIN_OPTS);

check-tagref:
	tagref

check-cljkondo:
	clj-kondo --lint .

check-zprint:
	zprint -c $(CLOJURE_SOURCES)

check: check-tagref check-cljkondo check-zprint
	@echo "All checks passed!"

test:
	clojure -M:poly test

test-all:
	clojure -M:poly test :all

test-coverage:
	clojure -X:dev:test:clofidence

install-antq:
	@if [ -f .antqtool.lastupdated ] && find .antqtool.lastupdated -mtime +15 -print | grep -q .; then \
		echo "Updating antq tool to the latest version..."; \
		clojure -Ttools install-latest :lib com.github.liquidz/antq :as antq; \
		touch .antqtool.lastupdated; \
	else \
		echo "Skipping antq tool update..."; \
	fi

.antqtool.lastupdated:
	touch .antqtool.lastupdated

upgrade-libs: .antqtool.lastupdated install-antq
	clojure -Tantq outdated :check-clojure-tools true :upgrade true

build: check
	@echo "Run deps-new build commands here!"


deploy: build
	@echo "Run fly.io deployment commands here!"

clean-projects:
	rm -rf projects/*/target/public

clean: clean-projects

serve:
	bb serve
