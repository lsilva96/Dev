/** 
 * XML Security Library example: Signing a file with a dynamicaly created template and an X509 certificate.
 * 
 * Signs a file using a dynamicaly created template, key from PEM file and
 * an X509 certificate. The signature has one reference with one enveloped 
 * transform to sign the whole document except the <dsig:Signature/> node 
 * itself. The key certificate is written in the <dsig:X509Data/> node.
 * 
 * This example was developed and tested with OpenSSL crypto library. The 
 * certificates management policies for another crypto library may break it.
 * 
 * Usage: 
 *      sign3 <xml-doc> <pem-key> 
 *
 * Example:
 *      ./sign3 sign3-doc.xml rsakey.pem rsacert.pem > sign3-res.xml
 *
 * The result signature could be validated using verify3 example:
 *      ./verify3 sign3-res.xml rootcert.pem
 *
 * This is free software; see Copyright file in the source
 * distribution for preciese wording.
 * 
 * Copyright (C) 2002-2003 Aleksey Sanin <aleksey@aleksey.com>
 */
 #include "hbapi.h"
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include <libxml/tree.h>
#include <libxml/xmlmemory.h>
#include <libxml/parser.h>

#ifndef XMLSEC_NO_XSLT
#include <libxslt/xslt.h>
#endif /* XMLSEC_NO_XSLT */

#include <xmlsec/xmlsec.h>
#include <xmlsec/xmltree.h>
#include <xmlsec/xmldsig.h>
#include <xmlsec/templates.h>
#include <xmlsec/crypto.h>

int sign_file(const char* xml_file, const char* key_file, const char* outfile ,const char * pass,const  char *  datafile);


/** 
 * sign_file:
 * @xml_file:           the XML file name.
 * @key_file:           the PEM private key file name.
 * @cert_file:          the x509 certificate PEM file.
 *
 * Signs the @xml_file using private key from @key_file and dynamicaly
 * created enveloped signature template. The certificate from @cert_file
 * is placed in the <dsig:X509Data/> node.
 *
 * Returns 0 on success or a negative value if an error occurs.
 */
int 
sign_file(const char* xml_file, const char* key_file, const char* outfile ,const char * pass, const char *  datafile) {
    xmlDocPtr doc = NULL;
    xmlNodePtr signNode = NULL;
    xmlNodePtr refNode = NULL;
    xmlNodePtr keyInfoNode = NULL;
    xmlSecDSigCtxPtr dsigCtx = NULL;
    int res = -1;
    
    assert(xml_file);
    assert(key_file);

    /* load doc file */
    doc = xmlParseFile(xml_file);
    if ((doc == NULL) || (xmlDocGetRootElement(doc) == NULL)){
        TraceLog("err.log", "Error: unable to parse file \"%s\"\n", xml_file);
        goto done;      
    }
    
    /* create signature template for RSA-SHA1 enveloped signature */
    signNode = xmlSecTmplSignatureCreate(doc, xmlSecTransformExclC14NId,
                                         xmlSecTransformRsaSha1Id, NULL);
    if(signNode == NULL) {
        TraceLog("err.log", "Error: failed to create signature template\n");
        goto done;              
    }

    /* add <dsig:Signature/> node to the doc */
    xmlAddChild(xmlDocGetRootElement(doc), signNode);
    
    /* add reference */
    refNode = xmlSecTmplSignatureAddReference(signNode, xmlSecTransformSha1Id,
                                        NULL, NULL, NULL);
    if(refNode == NULL) {
        TraceLog("err.log", "Error: failed to add reference to signature template\n");
        goto done;              
    }

    /* add enveloped transform */
    if(xmlSecTmplReferenceAddTransform(refNode, xmlSecTransformEnvelopedId) == NULL) {
        TraceLog("err.log", "Error: failed to add enveloped transform to reference\n");
        goto done;              
    }
    
    /* add <dsig:KeyInfo/> and <dsig:X509Data/> */
    keyInfoNode = xmlSecTmplSignatureEnsureKeyInfo(signNode, NULL);
    if(keyInfoNode == NULL) {
        TraceLog("err.log", "Error: failed to add key info\n");
        goto done;              
    }
    
    if(xmlSecTmplKeyInfoAddX509Data(keyInfoNode) == NULL) {
        TraceLog("err.log", "Error: failed to add X509Data node\n");
        goto done;              
    }

    /* create signature context, we don't need keys manager in this example */
    dsigCtx = xmlSecDSigCtxCreate(NULL);
    if(dsigCtx == NULL) {
       TraceLog("err.log","Error: failed to create signature context\n");
        goto done;
    }

    /* load private key, assuming that there is not password */
    dsigCtx->signKey = xmlSecCryptoAppKeyLoad(key_file, xmlSecKeyDataFormatPkcs12, pass, NULL, NULL);
    if(dsigCtx->signKey == NULL) {
        TraceLog("err.log","Error: failed to load private pem key from \"%s\"\n", key_file);
        goto done;
    }

    if (datafile)
       /* load certificate and add to the key */
       if(xmlSecCryptoAppKeyCertLoad(dsigCtx->signKey, datafile, xmlSecKeyDataFormatPem) < 0)
       {
           fprintf(stderr,"Error: failed to load pem certificate \"%s\"\n", key_file);
                  goto done;
       }

 
    /* set key name to the file name, this is just an example! */
    if(xmlSecKeySetName(dsigCtx->signKey, (const xmlChar *)key_file) < 0) {
        fprintf(stderr,"Error: failed to set key name for key from \"%s\"\n",(const xmlChar *) key_file);
        goto done;
    }

    /* sign the template */
    if(xmlSecDSigCtxSign(dsigCtx, signNode) < 0) {
        TraceLog("err.log","Error: signature failed\n");
        goto done;
    }
        
    /* print signed document to stdout */
    //xmlDocDump(stdout, doc);
    xmlSaveFile(outfile,doc);
    
    /* success */
    res = 0;

done:    
    /* cleanup */
    if(dsigCtx != NULL) {
        xmlSecDSigCtxDestroy(dsigCtx);
    }
    
    if(doc != NULL) {
        xmlFreeDoc(doc); 
    }
    return(res);
}

int 
sign_fileex(const char* tmpl_file, const char* key_file, const char* outfile ,const char * pass) {
    xmlDocPtr doc = NULL;
    xmlNodePtr node = NULL;
    xmlSecDSigCtxPtr dsigCtx = NULL;
    int res = -1;
    
    assert(tmpl_file);
    assert(key_file);

    /* load template */
    doc = xmlParseFile(tmpl_file);
    if ((doc == NULL) || (xmlDocGetRootElement(doc) == NULL)){
          TraceLog("err.log", "Error: unable to parse file \"%s\"\n", tmpl_file);
        goto done;      
    }
    
    /* find start node */
    node = xmlSecFindNode(xmlDocGetRootElement(doc), xmlSecNodeSignature, xmlSecDSigNs);
    if(node == NULL) {
         TraceLog("err.log", "Error: start node not found in \"%s\"\n", tmpl_file);
        goto done;      
    }

    /* create signature context, we don't need keys manager in this example */
    dsigCtx = xmlSecDSigCtxCreate(NULL);
    if(dsigCtx == NULL) {
          TraceLog("err.log","Error: failed to create signature context\n");
        goto done;
    }

    /* load private key, assuming that there is not password */
    dsigCtx->signKey = xmlSecCryptoAppKeyLoad(key_file, xmlSecKeyDataFormatPkcs12, pass, NULL, NULL);
    if(dsigCtx->signKey == NULL) {
          TraceLog("err.log","Error: failed to load private pem key from \"%s\"\n", key_file);
        goto done;
    }

    /* set key name to the file name, this is just an example! */
    if(xmlSecKeySetName(dsigCtx->signKey, (const xmlChar * )key_file) < 0) {
      TraceLog("err.log","Error: failed to set key name for key from \"%s\"\n", key_file);
        goto done;
    }

    /* sign the template */
    if(xmlSecDSigCtxSign(dsigCtx, node) < 0) {
        TraceLog("err.log","Error: signature failed\n");
        goto done;
    }
        
    /* print signed document to stdout */
    //xmlDocDump(stdout, doc);
    xmlSaveFile(outfile,doc);
    
    /* success */
    res = 0;

done:    
    /* cleanup */
    if(dsigCtx != NULL) {
        xmlSecDSigCtxDestroy(dsigCtx);
    }
    
    if(doc != NULL) {
        xmlFreeDoc(doc); 
    }
    return(res);
}



HB_FUNC( SIGNXML)
{
       const char* xml_file= hb_parc(1);
       const char* key_file = hb_parc(2);
        const char* outfile= hb_parc(3 ) ;
        const char * pass = hb_parc( 4 ) ;
        const char *  datafile = hb_parc( 5);
    xmlInitParser();
    LIBXML_TEST_VERSION
    xmlLoadExtDtdDefaultValue = XML_DETECT_IDS | XML_COMPLETE_ATTRS;
    xmlSubstituteEntitiesDefault(1);
#ifndef XMLSEC_NO_XSLT
    xmlIndentTreeOutput = 1; 
#endif /* XMLSEC_NO_XSLT */
                
    /* Init xmlsec library */
    if(xmlSecInit() < 0) {
        TraceLog("err.log", "Error: xmlsec initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Check loaded library version */
    if(xmlSecCheckVersion() != 1) {
        TraceLog("err.log", "Error: loaded xmlsec library version is not compatible.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Load default crypto engine if we are supporting dynamic
     * loading for xmlsec-crypto libraries. Use the crypto library
     * name ("openssl", "nss", etc.) to load corresponding 
     * xmlsec-crypto library.
     */
#ifdef XMLSEC_CRYPTO_DYNAMIC_LOADING
   if(xmlSecCryptoDLLoadLibrary("openssl") < 0 )
   {
                               hb_retnl( -1 ) ; return ;
   }
#endif /* XMLSEC_CRYPTO_DYNAMIC_LOADING */

    /* Init crypto library */
    if(xmlSecCryptoAppInit(NULL) < 0) {
        TraceLog("err.log", "Error: crypto initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Init xmlsec-crypto library */
    if(xmlSecCryptoInit() < 0) {
        TraceLog("err.log", "Error: xmlsec-crypto initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    if(sign_file( xml_file, key_file, outfile , pass, datafile) < 0) {
        hb_retnl( -1 ) ; return ;
    }    
    
    /* Shutdown xmlsec-crypto library */
    xmlSecCryptoShutdown();
    
    /* Shutdown crypto library */
    xmlSecCryptoAppShutdown();
    
    /* Shutdown xmlsec library */
    xmlSecShutdown();

    /* Shutdown libxslt/libxml */
#ifndef XMLSEC_NO_XSLT
    xsltCleanupGlobals();            
#endif /* XMLSEC_NO_XSLT */
    xmlCleanupParser();
    
    hb_retnl( 0);return;
}


HB_FUNC( SIGNXMLEX)
{
       const char* xml_file= hb_parc(1);
       const char* key_file = hb_parc(2);
        const char* outfile= hb_parc(3 ) ;
        const char * pass = hb_parc( 4 ) ;
//        const char *  datafile = hb_parc( 5);
    xmlInitParser();
    LIBXML_TEST_VERSION
    xmlLoadExtDtdDefaultValue = XML_DETECT_IDS | XML_COMPLETE_ATTRS;
    xmlSubstituteEntitiesDefault(1);
#ifndef XMLSEC_NO_XSLT
    xmlIndentTreeOutput = 1; 
#endif /* XMLSEC_NO_XSLT */
                
    /* Init xmlsec library */
    if(xmlSecInit() < 0) {
        TraceLog("err.log", "Error: xmlsec initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Check loaded library version */
    if(xmlSecCheckVersion() != 1) {
        TraceLog("err.log", "Error: loaded xmlsec library version is not compatible.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Load default crypto engine if we are supporting dynamic
     * loading for xmlsec-crypto libraries. Use the crypto library
     * name ("openssl", "nss", etc.) to load corresponding 
     * xmlsec-crypto library.
     */
#ifdef XMLSEC_CRYPTO_DYNAMIC_LOADING
   if(xmlSecCryptoDLLoadLibrary("openssl") < 0 )
   {
                               hb_retnl( -1 ) ; return ;
   }
#endif /* XMLSEC_CRYPTO_DYNAMIC_LOADING */

    /* Init crypto library */
    if(xmlSecCryptoAppInit(NULL) < 0) {
        TraceLog("err.log", "Error: crypto initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    /* Init xmlsec-crypto library */
    if(xmlSecCryptoInit() < 0) {
        TraceLog("err.log", "Error: xmlsec-crypto initialization failed.\n");
        hb_retnl( -1 ) ; return ;
    }

    if(sign_fileex( xml_file, key_file, outfile , pass ) < 0) {
        hb_retnl( -1 ) ; return ;
    }    
    
    /* Shutdown xmlsec-crypto library */
    xmlSecCryptoShutdown();
    
    /* Shutdown crypto library */
    xmlSecCryptoAppShutdown();
    
    /* Shutdown xmlsec library */
    xmlSecShutdown();

    /* Shutdown libxslt/libxml */
#ifndef XMLSEC_NO_XSLT
    xsltCleanupGlobals();            
#endif /* XMLSEC_NO_XSLT */
    xmlCleanupParser();
    
    hb_retnl( 0);return;
}
