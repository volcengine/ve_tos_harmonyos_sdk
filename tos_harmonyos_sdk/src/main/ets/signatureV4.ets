/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { hashSha256ToStr, hmacSha256ToStr, hmacSha256ToUint8Array, parse, stringify } from './crypto';
import { Headers } from './types/common';
import { getSortedQueryString } from './utils/common';

export interface ISigCredentials {
  GetSecretKey(): string;
  GetAccessKey(): string;
}

export interface ISigOptions {
  sigName?: string;
  endpoints?: string;
  bucket?: string;
  headers?: Record<string, string | undefined>;
  region?: string;
  serviceName?: string;
  algorithm?: string;
  path: string;
  method: string;
  query?: string;
  datetime?: string;
  host?: string;
  port?: number;
  policy?: Policy;
}

export interface ISigQueryOptions extends Omit<ISigOptions, 'query'> {
  query?: Record<string, string | undefined>;
}

interface Policy {
  conditions: string[][]
}

export interface ISigPolicyQuery {
  policy?: Policy;
}

interface ISignV4Opt {
  algorithm?: string;
  region?: string;
  serviceName?: string;
  securityToken?: string;
  bucket: string;
}
const v4Identifier = 'request';
export function isDefaultPort(port?: number) {
  if (port && port !== 80 && port !== 443) {
    return false;
  }
  return true;
}

export enum SIG_QUERY  {
  algorithm = 'tos-algorithm',
  expiration= 'tos-expiration',
  signame= 'tos-signame',
  signature= 'tos-signature',

  v4_algorithm= 'X-Tos-Algorithm',
  v4_credential= 'X-Tos-Credential',
  v4_date= 'X-Tos-Date',
  v4_expires= 'X-Tos-Expires',
  v4_signedHeaders= 'X-Tos-SignedHeaders',
  v4_security_token= 'X-Tos-Security-Token',
  v4_signature=  'X-Tos-Signature',
  v4_content_sha= 'X-Tos-Content-Sha256',
  v4_policy= 'X-Tos-Policy',
};

export class SignersV4 {
  private options: ISignV4Opt;
  private credentials: ISigCredentials;

  constructor(opt: ISignV4Opt, credentials: ISigCredentials) {
    this.options = opt;
    this.credentials = credentials;
  }

  /*
   * normal v4 signature
   * */
  public signature = (
    opt: ISigOptions,
    expiredAt: number,
    credentials?: ISigCredentials
  ) => {
    if (!credentials) {
      credentials = this.credentials;
    }
    const parts: string[] = [];
    const datatime = opt.datetime as string;
    const credString = this.credentialString(datatime);
    parts.push(
      this.options.algorithm +
        ' Credential=' +
      credentials.GetAccessKey() +
        '/' +
        credString
    );

    parts.push('SignedHeaders=' + this.signedHeaders(opt));
    parts.push('Signature=' + this.authorization(opt, credentials, 0));
    return parts.join(', ');
  };
  public signatureHeader = (
    opt: ISigOptions,
    expiredAt?: number,
    credentials?: ISigCredentials
  ): Map<string, string> => {
    // const datetime = (new Date(new Date().toUTCString())).Format("yyyyMMddTHHmmssZ")
    opt.datetime = this.getDateTime();
    const header = new Map<string, string>();
    /* istanbul ignore if */
    if (!opt.headers) {
      const h: Record<string, string> = {};
      opt.headers = h;
    }

    opt.headers.host = `${opt.host}`;
    /* istanbul ignore if */
    if (!isDefaultPort(opt.port)) {
      opt.headers.host += ':' + opt.port;
    }
    /* istanbul ignore if */
    if (opt.endpoints) {
      opt.headers.host = `${this.options.bucket}.${opt.endpoints}`;
    }

    header.set('host', opt.headers.host); // opt.endpoints as string)
    header.set('x-tos-date', opt.datetime); // opt.datetime)
    /* istanbul ignore if
      if (opt.endpoints) {
          let bucket = this.options.bucket;
          if (opt.bucket) {
              bucket = opt.bucket;
          }
          if (!opt.path || opt.path === '/' || opt.path === `/${bucket}`) {
              opt.path = '/' + bucket;
          } else {
              opt.path = '/' + bucket + opt.path;
          }
      }
      */
    if (!opt.headers['x-tos-content-sha256']) {
      header.set('x-tos-content-sha256', this.hexEncodedBodyHash());
    }

    if (this.options.securityToken) {
      header.set('x-tos-security-token', this.options.securityToken);
    }
    // x-tos- must to be signatured
    header.forEach((value, key) => {
      if (key.startsWith('x-tos')) {
        if (opt.headers) {
          opt.headers[key] = value;
        }
      }
    });
    opt.path = this.getEncodePath(opt.path);
    const sign = this.signature(opt, 0, credentials);
    header.set('authorization', sign);

    return header;
  };
  // public gnrCopySig = (
  //   opt: ISigOptions,
  //   credentials: ISigCredentials
  // ): { key: string; value: string } => {
  //   return { key: '', value: '' };
  // };
  //
  // public getSignature = (
  //   opt: ISigOptions,
  //   expiredAt: number
  // ): { key: ''; value: '' } => {
  //   return { key: '', value: '' };
  // };
  //
  public getSignatureQuery = (
    opt: ISigQueryOptions,
    expiredAt: number
  ):  Record<string, string | undefined> => {
    opt.datetime = this.getDateTime();
    if (!opt.headers) {
      const h: Record<string, string> = {};
      opt.headers = h;
    }

    opt.headers.host = `${opt.host}`;
    if (!isDefaultPort(opt.port)) {
      opt.headers.host += ':' + opt.port;
    }

    opt.path = this.getEncodePath(opt.path);
    if (opt.endpoints) {
      opt.headers.host = `${this.options.bucket}.${opt.endpoints}`;
      // opt.path = `${opt.path}`;
    }

    opt.headers[SIG_QUERY.v4_date] = opt.datetime;
    const credString = this.credentialString(opt.datetime as string);
    const res: Record<string, string | undefined> = opt.query ? JSON.parse(JSON.stringify(opt.query)) : {};
    res[SIG_QUERY.v4_algorithm] =  this.options.algorithm;
    res[SIG_QUERY.v4_content_sha] =  this.hexEncodedBodyHash();
    res[SIG_QUERY.v4_credential] = this.credentials.GetAccessKey() + '/' + credString;
    res[SIG_QUERY.v4_date] = opt.datetime;
    res[SIG_QUERY.v4_expires] = String(expiredAt);
    res[SIG_QUERY.v4_signedHeaders] = this.signedHeaders({
      sigName: opt.sigName,
      endpoints:opt.endpoints,
      bucket: opt.bucket,
      headers: opt.headers,
      region: opt.region,
      serviceName: opt.serviceName,
      algorithm: opt.algorithm,
      path: opt.path,
      method: opt.method,
      query: getSortedQueryString(res),
      datetime: opt.datetime,
      host: opt.host,
      port: opt.port,
    });

    if (this.options.securityToken) {
      res[SIG_QUERY.v4_security_token] = this.options.securityToken;
    }

    const newOpt: ISigOptions = {
      sigName: opt.sigName,
      endpoints:opt.endpoints,
      bucket: opt.bucket,
      headers: opt.headers,
      region: opt.region,
      serviceName: opt.serviceName,
      algorithm: opt.algorithm,
      path: opt.path,
      method: opt.method,
      query: getSortedQueryString(res),
      datetime: opt.datetime,
      host: opt.host,
      port: opt.port,
    }

    res[SIG_QUERY.v4_signature] = this.authorization(
      newOpt,
      this.credentials,
      expiredAt
    );
    return res;
  };
  //
  public getSignaturePolicyQuery = (
    opt: ISigPolicyQuery,
    expiredAt: number
  ): Record<string, string | undefined> => {
    const datetime = this.getDateTime()
    const newOpt: ISigOptions = {
      datetime,
      // method 和 path 不会参与算签，这里为了兼容类型给空字符串
      method: '',
      path: '',
      policy: opt.policy
    }

    const credString = this.credentialString(datetime);

    const res: Record<string, string | undefined> = {
      [SIG_QUERY.v4_algorithm]: this.options.algorithm,
      [SIG_QUERY.v4_credential]:
      this.credentials.GetAccessKey() + '/' + credString,
      [SIG_QUERY.v4_date]: datetime,
      [SIG_QUERY.v4_expires]: '' + expiredAt,
      [SIG_QUERY.v4_policy]: stringify(
        parse(JSON.stringify(opt.policy), 'utf-8'),
        'base64'
      ),
    };
    if (this.options.securityToken) {
      res[SIG_QUERY.v4_security_token] = this.options.securityToken;
    }
    newOpt.query = getSortedQueryString(res);

    res[SIG_QUERY.v4_signature] = this.authorization(
      newOpt,
      this.credentials,
      expiredAt
    );
    return res;
  };

  private hexEncodedBodyHash = (headers?: Headers): string => {
    if (headers?.['x-tos-content-sha256']) {
      return headers?.['x-tos-content-sha256'];
    }
    return 'UNSIGNED-PAYLOAD';
  };
  //
  private authorization = (
    opt: ISigOptions,
    credentials: ISigCredentials,
    expiredAt: number
  ): string => {
    /* istanbul ignore if */
    if (!opt.datetime) {
      return '';
    }

    const signingKey = this.getSigningKey(
      credentials,
      opt.datetime.substr(0, 8)
    );
    const res = hmacSha256ToStr(signingKey, this.stringToSign(opt.datetime, opt), 'hex');
    return res;
  };
  //
  private getDateTime = () => {
    const date = new Date(new Date().toUTCString());
    const datetime =
      date
        .toISOString()
        .replace(/\..+/, '')
        .replace(/-/g, '')
        .replace(/:/g, '') + 'Z';
    return datetime;
  };
  private credentialString = (datetime: string): string => {
    return this.createScope(
      datetime.substr(0, 8),
      this.options.region,
      this.options.serviceName
    );
  };
  //
  private createScope = (date: string, region?: string, serviceName?: string) => {
    return [date.substr(0, 8), region, serviceName, v4Identifier].join('/');
  };

  private getSigningKey = (credentials: ISigCredentials, date: string) : Uint8Array => {
    const kDate = hmacSha256ToUint8Array(credentials.GetSecretKey(), date);
    const kRegion = hmacSha256ToUint8Array(kDate, this.options.region as string);
    const kService = hmacSha256ToUint8Array(kRegion, this.options.serviceName as string);
    const signingKey = hmacSha256ToUint8Array(kService, v4Identifier);
    return signingKey;
  };
  //
  private stringToSign = (datetime: string, opt: ISigOptions) => {
    /* istanbul ignore if */
    if (!this.options.algorithm) {
      return '';
    }

    const parts: string[] = [];
    parts.push(this.options.algorithm);
    parts.push(datetime);
    parts.push(this.credentialString(datetime));
    const canonicalString =
      !!opt.policy
        ? this.canonicalStringPolicy(opt)
        : this.canonicalString(opt);
    parts.push(this.hexEncodedHash(canonicalString) as string);
    return parts.join('\n');
  };
  private hexEncodedHash = (str: string) => {
    return hashSha256ToStr(str, 'hex');
  };
  private canonicalString = (opt: ISigOptions) => {
    const parts: string[] = [];
    parts.push(opt.method);
    parts.push(opt.path);
    parts.push(this.getEncodePath(opt.query as string, false));
    parts.push(this.canonicalHeaders(opt) + '\n');
    parts.push(this.signedHeaders(opt));
    parts.push(this.hexEncodedBodyHash(opt.headers));
    return parts.join('\n');
  };
  //
  private canonicalStringPolicy = (opt: ISigOptions) => {
    const parts: string[] = [];
    parts.push(this.getEncodePath(opt.query as string, false));
    parts.push(this.hexEncodedBodyHash());
    return parts.join('\n');
  };

  private canonicalHeaders = (opt: ISigOptions) => {
    const parts: string[] = [];
    const needSignHeaders = getNeedSignedHeaders(opt.headers);

    for (let key of needSignHeaders) {
      if(opt.headers) {
        const value = opt.headers[key];
        key = key.toLowerCase();
        parts.push(key + ':' + this.canonicalHeaderValues(String(value)));
      }
    }

    return parts.join('\n');
  };
  //
  private canonicalHeaderValues = (values: string) => {
    return values.replace(/\s+/g, ' ').replace(/^\s+|\s+$/g, '');
  };
  //
  private signedHeaders = (opt: ISigOptions) => {
    const keys: string[] = [];
    const needSignHeaders = getNeedSignedHeaders(opt.headers);

    for (let key of needSignHeaders) {
      key = key.toLowerCase();
      keys.push(key);
    }

    return keys.sort().join(';');
  };

  //
  // /**
  //  * ! * ' () aren't transformed by encodeUrl, so they need be handled
  //  */
  private getEncodePath(path?: string, encodeAll: boolean = true): string {
    if (!path) {
      return '';
    }

    let tmpPath = path;
    if (encodeAll) {
      tmpPath = path.replace(/%2F/g, '/');
    }
    tmpPath = tmpPath.replace(/\(/g, '%28');
    tmpPath = tmpPath.replace(/\)/g, '%29');
    tmpPath = tmpPath.replace(/!/g, '%21');
    tmpPath = tmpPath.replace(/\*/g, '%2A');
    tmpPath = tmpPath.replace(/\'/g, '%27');
    return tmpPath;
  }
}


export class ISigV4Credentials implements ISigCredentials {
  public securityToken: string;
  public secretAccessKey: string;
  public accessKeyId: string;

  constructor(
    securityToken?: string,
    secretAccessKey?: string,
    accessKeyId?: string
  ) {
    this.accessKeyId = accessKeyId as string;
    this.secretAccessKey = secretAccessKey as string;
    this.securityToken = securityToken as string;
  }

  public GetAccessKey(): string {
    return this.accessKeyId;
  }

  public GetSecretKey(): string {
    return this.secretAccessKey;
  }
}


function getNeedSignedHeaders(headers: Record<string, string | undefined> | undefined) {
  const needSignHeaders: string[] = [];
  if (headers) {
    Object.keys(headers).forEach((key: string) => {
      if (key === 'host' || key.startsWith('x-tos-')) {
        if (headers[key] != null) {
          needSignHeaders.push(key);
        }
      }
    })
  }
  ;
  return needSignHeaders.sort();
}