#
CURL	?= $(shell if test -f /usr/bin/curl ; then echo "curl -H Pragma: -O -R -S --fail --show-error" ; fi)
WGET	?= $(shell if test -f /usr/bin/wget ; then echo "wget -nd -m" ; fi)
CLIENT	?= $(if $(WGET),$(WGET),$(if $(CURL),$(CURL)))
AWK	= awk
SHA1SUM	= sha1sum
SED	= sed

# TD 21.03.2014: Using "--with baseonly" to avoid building all the special variants.
RPM_ARCH_BUILDOPT   = --with baseonly --without tools --without debug --without debuginfo
RPM_NOARCH_BUILDOPT = --without tools --without debug --without debuginfo
# this is passed on the command line as the full path to <build>/SPECS/kernel.spec

SPECFILE = kernel.spec

# Thierry - when called from within the build, PWD is /build
PWD=$(shell pwd)

# get nevr from specfile.
ifndef NAME
NAME := $(shell rpm $(RPMDEFS) $(DISTDEFS) -q --qf "%{NAME}\n" --specfile $(SPECFILE) | head -1)
endif
ifndef EPOCH
EPOCH := $(shell rpm $(RPMDEFS) $(DISTDEFS) -q --qf "%{EPOCH}\n" --specfile $(SPECFILE) | head -1 | sed 's/(none)//')
endif
ifeq ($(EPOCH),(none))
override EPOCH := ""
endif
ifndef VERSION
VERSION := $(shell rpm $(RPMDEFS) $(DISTDEFS) -q --qf "%{VERSION}\n" --specfile $(SPECFILE)| head -1)
endif
ifndef RELEASE
RELEASE := $(shell rpm $(RPMDEFS) $(DISTDEFS) -q --qf "%{RELEASE}\n" --specfile $(SPECFILE)| head -1)
endif


# TD 21.03.2014: Needs to define _specdir. Otherwise, the spec file is not found.
#                This triggers "patch  xxxxx  not listed as a source patch in specfile",
#                since the specfile cannot be opened by "grep".
# TD 21.03.2014: The spec file relies on "bash" for regexp and "[[". Set it by _buildshell.
PREPARCH ?= noarch
RPMDIRDEFS = \
   --define "_specdir $(PWD)" \
   --define "_sourcedir $(PWD)/SOURCES" \
   --define "_builddir $(PWD)" \
   --define "_srcrpmdir $(PWD)" \
   --define "_rpmdir $(PWD)" \
   --define "_buildshell /bin/bash"

# use the stock source rpm, unwrap it,
# copy the downloaded material
# install our own specfile and patched patches
# and patch configs
# then rewrap with rpm
srpm:
	./fetch-upstream-kernel
	mkdir -p SOURCES SRPMS
	(cd SOURCES; cp ../upstream-kernel/* .; \
	 cp ../$(notdir $(SPECFILE)) . ; cp ../*.patch .; cp ../config-planetlab .; \
	 for downloaded in $(SOURCEFILES) ; do cp ../$$downloaded . ; done ; \
	 cat config-planetlab >> config-generic)
	./rpmmacros.sh
	export HOME=$(shell pwd) ; rpmbuild $(RPMDIRDEFS) $(RPMDEFS) --nodeps -bs $(SPECFILE)
	# FIXME!!! rpmbuild $(RPMDIRDEFS) $(RPMDEFS) $(RPM_NOARCH_BUILDOPT) --nodeps -bp --target $(PREPARCH) $(SPECFILE)

TARGET ?= $(shell uname -m)
rpm: srpm
	# 25.03.2014: Call rpmbuild for noarch. This generates the kernel-docs package.
	# ??? FIXME!!! rpmbuild $(RPMDIRDEFS) $(RPMDEFS) $(RPM_NOARCH_BUILDOPT) --nodeps --target $(PREPARCH) -bb $(SPECFILE)
	# Now, run the build for the architecture-specific packages.
	rpmbuild $(RPMDIRDEFS) $(RPMDEFS) $(RPM_ARCH_BUILDOPT) --nodeps --target $(TARGET) -bb $(SPECFILE)

distclean: whipe

whipe: clean
	rm -f *.rpm
	rm -rf kernel-*
	rm -rf x86_64

clean:
	rm -f kernel-*.src.rpm
	rm -rf BUILDROOT SOURCES SPECS SRPMS tmp
	rm -rf upstream-kernel
