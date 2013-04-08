#!/bin/sh

set -v
rm -f ecdump_objs.cg ecdump_objs.defs
cp bld/objects/ecdump_new.cg    ecdump_objs.cg
cp bld/objects/ecdump_new.defs  ecdump_objs.defs

#note - method files are picked up from bld/objects/m/* - copy to m/ when ready.
#cp bld/objects/ecResources.defs	ecResources.defs
#cp bld/objects/ecResource.defs	ecResource.defs
#
#cp bld/objects/m/ecResources_mthd.defs	m/ecResources_mthd.defs
#cp bld/objects/m/ecResource_mthd.defs	m/ecResource_mthd.defs
#
#cp bld/objects/ecCloud.defs	ecCloud.defs
#cp bld/objects/m/ecCloud_mthd.defs	m/ecCloud_mthd.defs
