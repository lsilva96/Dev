/*
 * Summary: Interfaces, constants and types related to the XSLT engine
 * Description: Interfaces, constants and types related to the XSLT engine
 *
 * Copy: See Copyright for the status of this software.
 *
 * Author: Daniel Veillard
 */

#ifndef __XML_XSLT_H__
#define __XML_XSLT_H__

#include <libxml/tree.h>
//#include <libxml/xsltexports.h>
#define __XSLT_EXPORTS_H__

/**
 * XSLTPUBFUN:
 * XSLTPUBFUN, XSLTPUBVAR, XSLTCALL
 *
 * Macros which declare an exportable function, an exportable variable and
 * the calling convention used for functions.
 *
 * Please use an extra block for every platform/compiler combination when
 * modifying this, rather than overlong #ifdef lines. This helps
 * readability as well as the fact that different compilers on the same
 * platform might need different definitions.
 */

/**
 * XSLTPUBFUN:
 *
 * Macros which declare an exportable function
 */
#define XSLTPUBFUN
/**
 * XSLTPUBVAR:
 *
 * Macros which declare an exportable variable
 */
#define XSLTPUBVAR extern
/**
 * XSLTCALL:
 *
 * Macros which declare the called convention for exported functions
 */
#define XSLTCALL

/** DOC_DISABLE */

/* Windows platform with MS compiler */
#if defined(_WIN32) && defined(_MSC_VER)
  #undef XSLTPUBFUN
  #undef XSLTPUBVAR
  #undef XSLTCALL
  #if defined(IN_LIBXSLT) && !defined(LIBXSLT_STATIC)
    #define XSLTPUBFUN __declspec(dllexport)
    #define XSLTPUBVAR __declspec(dllexport)
  #else
    #define XSLTPUBFUN
    #if !defined(LIBXSLT_STATIC)
      #define XSLTPUBVAR __declspec(dllimport) extern
    #else
      #define XSLTPUBVAR extern
    #endif
  #endif
  #define XSLTCALL __cdecl
  #if !defined _REENTRANT
    #define _REENTRANT
  #endif
#endif

/* Windows platform with Borland compiler */
#if defined(_WIN32) && defined(__BORLANDC__)
  #undef XSLTPUBFUN
  #undef XSLTPUBVAR
  #undef XSLTCALL
  #if defined(IN_LIBXSLT) && !defined(LIBXSLT_STATIC)
    #define XSLTPUBFUN __declspec(dllexport)
    #define XSLTPUBVAR __declspec(dllexport) extern
  #else
    #define XSLTPUBFUN
    #if !defined(LIBXSLT_STATIC)
      #define XSLTPUBVAR __declspec(dllimport) extern
    #else
      #define XSLTPUBVAR extern
    #endif
  #endif
  #define XSLTCALL __cdecl
  #if !defined _REENTRANT
    #define _REENTRANT
  #endif
#endif

/* Windows platform with GNU compiler (Mingw) */
#if defined(_WIN32) && defined(__MINGW32__)
  #undef XSLTPUBFUN
  #undef XSLTPUBVAR
  #undef XSLTCALL
/*
  #if defined(IN_LIBXSLT) && !defined(LIBXSLT_STATIC)
*/
  #if !defined(LIBXSLT_STATIC)
    #define XSLTPUBFUN __declspec(dllexport)
    #define XSLTPUBVAR __declspec(dllexport) extern
  #else
    #define XSLTPUBFUN
    #if !defined(LIBXSLT_STATIC)
      #define XSLTPUBVAR __declspec(dllimport) extern
    #else
      #define XSLTPUBVAR extern
    #endif
  #endif
  #define XSLTCALL __cdecl
  #if !defined _REENTRANT
    #define _REENTRANT
  #endif
#endif

/* Cygwin platform, GNU compiler */
#if defined(_WIN32) && defined(__CYGWIN__)
  #undef XSLTPUBFUN
  #undef XSLTPUBVAR
  #undef XSLTCALL
  #if defined(IN_LIBXSLT) && !defined(LIBXSLT_STATIC)
    #define XSLTPUBFUN __declspec(dllexport)
    #define XSLTPUBVAR __declspec(dllexport)
  #else
    #define XSLTPUBFUN
    #if !defined(LIBXSLT_STATIC)
      #define XSLTPUBVAR __declspec(dllimport) extern
    #else
      #define XSLTPUBVAR
    #endif
  #endif
  #define XSLTCALL __cdecl
#endif

/* Compatibility */
#if !defined(LIBXSLT_PUBLIC)
#define LIBXSLT_PUBLIC XSLTPUBVAR
#endif



#ifdef __cplusplus
extern "C" {
#endif

/**
 * XSLT_DEFAULT_VERSION:
 *
 * The default version of XSLT supported.
 */
#define XSLT_DEFAULT_VERSION     "1.0"

/**
 * XSLT_DEFAULT_VENDOR:
 *
 * The XSLT "vendor" string for this processor.
 */
#define XSLT_DEFAULT_VENDOR      "libxslt"

/**
 * XSLT_DEFAULT_URL:
 *
 * The XSLT "vendor" URL for this processor.
 */
#define XSLT_DEFAULT_URL         "http://xmlsoft.org/XSLT/"

/**
 * XSLT_NAMESPACE:
 *
 * The XSLT specification namespace.
 */
#define XSLT_NAMESPACE ((xmlChar *) "http://www.w3.org/1999/XSL/Transform")

/**
 * XSLT_PARSE_OPTIONS:
 *
 * The set of options to pass to an xmlReadxxx when loading files for
 * XSLT consumption.
 */
#define XSLT_PARSE_OPTIONS \
 XML_PARSE_NOENT | XML_PARSE_DTDLOAD | XML_PARSE_DTDATTR | XML_PARSE_NOCDATA

/**
 * xsltMaxDepth:
 *
 * This value is used to detect templates loops.
 */
XSLTPUBVAR int xsltMaxDepth;

/**
 * xsltEngineVersion:
 *
 * The version string for libxslt.
 */
XSLTPUBVAR const char *xsltEngineVersion;

/**
 * xsltLibxsltVersion:
 *
 * The version of libxslt compiled.
 */
XSLTPUBVAR const int xsltLibxsltVersion;

/**
 * xsltLibxmlVersion:
 *
 * The version of libxml libxslt was compiled against.
 */
XSLTPUBVAR const int xsltLibxmlVersion;

/*
 * Global initialization function.
 */

XSLTPUBFUN void XSLTCALL
		xsltInit		(void);

/*
 * Global cleanup function.
 */
XSLTPUBFUN void XSLTCALL	
		xsltCleanupGlobals	(void);

#ifdef __cplusplus
}
#endif

#endif /* __XML_XSLT_H__ */

