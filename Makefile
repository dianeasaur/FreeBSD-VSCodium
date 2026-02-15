PORTNAME=       vscodium
PORTVERSION=    1.109.21026
VER_SHORT=      1.109.2
VER_COMMIT=     591199df409fbf59b4b52d5ad4ee0470152a9b31
CATEGORIES=     editors

DIST_SUBDIR=    ${PORTNAME}
SUB_FILES=      ${PORTNAME}

MAINTAINER=     4983626+dianeasaur@users.noreply.github.com
COMMENT=        VSCodium (Visual Studio Code)
WWW=            https://vscodium.com

LICENSE=        MIT
LICENSE_FILE=   ${WRKSRC}/LICENSE

USES=           desktop-file-utils display:test electron:40 gl \
	gmake gnome gssapi:mit iconv:wchar_t jpeg localbase:ldflags \
	nodejs:24,build pkgconfig python:build xorg

USE_GITHUB=     yes
GH_TUPLE=       VSCodium:vscodium:${PORTVERSION} \
	microsoft:vscode:${VER_COMMIT}:vscode
	#gabime:spdlog:${_SPDLOG_VER}:include/spdlog

USE_ELECTRON=   npm:npm appbuilder:devel prefetch extract rebuild build:builder

EXTRACT_DEPENDS=jq:textproc/jq \
	node24>0:www/node24
BUILD_DEPENDS=  zip:archivers/zip \
	jq:textproc/jq \
	rg:textproc/ripgrep
LIB_DEPENDS=    libpcre2-8.so:devel/pcre2 \
	libfreetype.so:print/freetype2
RUN_DEPENDS=    xdg-open:devel/xdg-utils \
	bash:shells/bash
TEST_DEPENDS=   bash:shells/bash

_SPDLOG_VER=    v1.17.0

BINARY_ALIAS=   python=${PYTHON_CMD}

USE_XORG=       x11 xcb xcomposite xcursor xdamage xext xfixes xi xkbfile \
		xrandr xrender xscrnsaver xtst
USE_GL=         gbm gl glesv2
USE_GNOME=      atk cairo pango gdkpixbuf gtk30 libxml2 libxslt
USE_ELECTRON=   npm:npm

DATADIR=        ${PREFIX}/share/code-oss
TMPDIR=         ${WRKDIR}
BUNDLE_LIBS=    yes

MAKE_ENV+=      OS_NAME="freebsd"
MAKE_ENV+=      PKG_BUILD="yes"
MAKE_ENV+=      RELEASE_VERSION=${VER_SHORT}
MAKE_ENV+=      BUILD_SOURCEVERSION=${SOURCE_COMMIT_HASH}

# Don't create __pycache__ directory when executing node-gyp
# This is a workaround to avoid filesystem violations during poudriere build
MAKE_ENV+=      PYTHONDONTWRITEBYTECODE=1
TEST_ENV=       ${MAKE_ENV:C/TMPDIR=.*//}

UPSTREAM_ELECTRON_VER=  ${ELECTRON_VER}

.include <bsd.port.pre.mk>

pre-everything::
	@${ECHO_MSG} ""
	@${ECHO_MSG} "The limit imposed by poudriere(8) for the maximum number of files allowed to be"
	@${ECHO_MSG} "opened by a jail (default 1024) is exceeded during the build of ${PORTNAME}."
	@${ECHO_MSG} "To successfully build ${PORTNAME} with poudriere(8), you must add the following"
	@${ECHO_MSG} "line to poudriere.conf:"
	@${ECHO_MSG} "MAX_FILES_${PORTNAME}=8192"
	@${ECHO_MSG} ""

post-extract:
	@${MV} ${WRKDIR}/vscode-${VER_COMMIT} ${WRKSRC}/vscode
	@git init -b ${PORTVERSION} ${WRKSRC}
	@${ECHO_MSG} "===>  Removing source patches that conflict or will be applied in patching stage"
	@${RM} ${WRKSRC}/patches/extensions-disable-mangler.patch
	@${MV} ${WRKSRC}/vscode/.npmrc ${WRKSRC}/vscode/.npmrc.bak && \
		${CP} ${WRKSRC}/npmrc ${WRKSRC}/vscode/.npmrc
	@${ECHO_MSG} "===>  Splitting prepare script into two stages"
	@cd ${WRKSRC} && csplit -sf pv_stage prepare_vscode.sh '/^# {{{ install dependencies/' '{0}'
	@${MV} ${WRKSRC}/pv_stage00 ${WRKSRC}/prepare_vscode_stage1.sh
	@echo -e '#!/usr/bin/env bash' > ${WRKSRC}/prepare_vscode_stage2.sh
	@${CHMOD} 0750 ${WRKSRC}/prepare_vscode_stage1.sh
	@${CHMOD} 0750 ${WRKSRC}/prepare_vscode_stage2.sh
	@cat ${WRKSRC}/pv_stage01 >> ${WRKSRC}/prepare_vscode_stage2.sh
	@${RM} ${WRKSRC}/prepare_vscode.sh ${WRKSRC}/pv_stage01

post-extract-script:
	@${ECHO_MSG}  "===>  Executing prepare_vscode_stage1.sh"
	@cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} ./prepare_vscode_stage1.sh > ${WRKDIR}/stage1.log 2>&1

pre-patch:
	cd ${WRKSRC}/vscode && npm install --ignore-scripts \@vscode/spdlog@^0.15.7

post-patch:

pre-build:
	@${ECHO_MSG} "===> In pre-build"
	cd ${WRKSRC}/vscode && ${SETENV} ${MAKE_ENV} npm ci

do-build:

#cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} ./prepare_vscode_stage2.sh

do-install:

pre-test:

do-test:

build-remote-extension-host: configure pre-build

.include <bsd.port.post.mk>
