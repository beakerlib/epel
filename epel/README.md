# NAME

BeakerLib library distribution/epel

# DESCRIPTION

This library adds disabled epel repository.

# USAGE

To use this functionality you need to import library distribution/epel and add
following line to Makefile.

        @echo "RhtsRequires:    library(distribution/epel)" >> $(METADATA)

The repo is installed by epel-release package so it creates repo named epel,
epel-debuginfo, and epel-source, and the testing ones. All of them are disabled
by the library. To use them you should call yum with --enablerepo option, e.g.
'--enablerepo epel'. But be sure epel is avaivalbe, otherwise the repo is
unknown to yum.

Alternatively you can call `epelyum`  or `epel yum` instead of
`yum --enablerepo epel` which
would work also if epel is not available or `epel yum`. For example on Fedora.
Or use _epelIsAvailable_ to check actual availability of the epel repo.

# VARIABLES

# FUNCTIONS

# AUTHORS

- Dalibor Pospisil <dapospis@redhat.com>
