# A Perforce Client Specification.
#
#  Client:      The client name.
#  Update:      The date this specification was last modified.
#  Access:      The date this client was last used in any way.
#  Owner:       The Perforce user name of the user who owns the client
#               workspace. The default is the user who created the
#               client workspace.
#  Host:        If set, restricts access to the named host.
#  Description: A short description of the client (optional).
#  Root:        The base directory of the client workspace.
#  AltRoots:    Up to two alternate client workspace roots.
#  Options:     Client options:
#                      [no]allwrite [no]clobber [no]compress
#                      [un]locked [no]modtime [no]rmdir
#  SubmitOptions:
#                      submitunchanged/submitunchanged+reopen
#                      revertunchanged/revertunchanged+reopen
#                      leaveunchanged/leaveunchanged+reopen
#  LineEnd:     Text file line endings on client: local/unix/mac/win/share.
#  ServerID:    If set, restricts access to the named server.
#  View:        Lines to map depot files into the client workspace.
#  Stream:      The stream to which this client's view will be dedicated.
#               (Files in stream paths can be submitted only by dedicated
#               stream clients.) When this optional field is set, the
#               View field will be automatically replaced by a stream
#               view as the client spec is saved.
#
# Use 'p4 help client' to see more about client views and options.

Client:	ecscm-master

Update:	2013/05/09 13:51:18

Access:	2013/05/09 13:51:18

Owner:	ecdump

Description:
	SCM area for ecdump updates

Root:	/tmp/ecscm-master

Options:	noallwrite noclobber nocompress unlocked nomodtime normdir

SubmitOptions:	submitunchanged

LineEnd:	local

View:
	//depot/ecdumps/bnr/ecscm-master/... //ecscm-master/...

