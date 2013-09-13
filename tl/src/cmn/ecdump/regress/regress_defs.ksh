#setup script for regression tests

#determine PATH separator character:
unset PS; PS=':' ; _doscnt=`echo $PATH | grep -c ';'` ; [ $_doscnt -ne 0 ] && PS=';' ; unset _doscnt

#this is the install root for ecdump:
ECDUMP_SRCROOT="$SRCROOT/tl/src/cmn/ecdump"
REGRESS_SRCROOT="$ECDUMP_SRCROOT/regress"

#this is where we write test output:
TEST_ROOT=$ECDUMP_SRCROOT/bld/tst

ECDUMP_CGROOT="$ECDUMP_SRCROOT/srcgen/cgsrc/bld"
if [ ! -d $ECDUMP_SRCROOT ]; then
    2>&1 echo WARNING:  you must generate ecdump in $ECDUMP_CGROOT to test latest source
    #fall back to latest installed version:
    ECDUMP_CGROOT="$ECDUMP_SRCROOT"
fi

export PATH PERL_LIBPATH
PATH="${ECDUMP_CGROOT}${PS}$PATH"
PERL_LIBPATH="${ECDUMP_CGROOT};$PERL_LIBPATH"

REGRESS_TESTDB_PROPS="$TEST_ROOT/$REGRESS_TESTDB.props"
