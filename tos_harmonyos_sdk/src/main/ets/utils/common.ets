/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { CopyObjectOutput, GetObjectInput,
  GetObjectOutput,
  HeadObjectOutput,
  Reader,
  RequestInfo,SupportObjectBody } from '../types/model2';
import { Query, Headers, Any, Response } from '../types/common';
import { stream } from '@kit.ArkTS';
import { StorageClassType } from '../types/enum';
import { InnerGetObjectBasicOutput, InnerHeadObjectOutput } from '../types/inner';
import TosClientError from '../TosClientError';

export const withRequestInfo = (out: RequestInfo, resp: Response) => {
  out.StatusCode = resp.status;
  out.Headers = resp.headers as Headers;
  out.RequestID = resp.headers['x-tos-request-id'] ?? '';
  out.ID2 = resp.headers['x-tos-id-2'] ?? ''
}

export const withCopyObjectOutput = (res: Response): CopyObjectOutput => {
  const data = (res.data ?? {}) as Record<string, string>
  const out: Partial<CopyObjectOutput> = {
    ETag: data?.ETag ?? '',
    CopySourceVersionID: res.headers['x-tos-copy-source-version-id'],
    VersionID: res.headers['x-tos-version-id'],
    SSECAlgorithm: res.headers['x-tos-server-side-encryption-customer-algorithm'],
    SSECKeyMD5: res.headers['x-tos-server-side-encryption-customer-key-md5'],
  }
  if (data.LastModified) {
    out.LastModified = new Date(data.LastModified);
  }
  const out2 = out as CopyObjectOutput
  withRequestInfo(out2, res);
  return out2;
}

export const withHeadObjectOutput = (resp: Response): HeadObjectOutput => {
  const meta = getMeta(resp.headers)
  const output: InnerHeadObjectOutput = {
    ETag: resp.headers.etag ?? '',
    VersionID: resp.headers['x-tos-version-id'] ?? '',
    ContentLength: resp.headers['content-length'] ? Number(resp.headers['content-length']) : 0,
    ContentType: resp.headers['content-type'] ?? '',
    CacheControl: resp.headers['cache-control'],
    Expires: resp.headers['expires'] ? new Date(resp.headers['expires']) : undefined,
    ContentDisposition: resp.headers['content-disposition'] ? safeDecodeURIComponent(resp.headers['content-disposition']) : undefined,
    ContentEncoding: resp.headers['content-encoding'],
    ContentLanguage: resp.headers['content-language'],
    StorageClass: resp.headers['x-tos-storage-class'] as StorageClassType,
    SSECAlgorithm: resp.headers['x-tos-server-side-encryption-customer-algorithm'],
    SSECKeyMD5: resp.headers['x-tos-server-side-encryption-customer-key-md5'],
    Meta: meta,
    HashCrc64ecma: resp.headers['x-tos-hash-crc64ecma'] ?? ''
  };

  const output2 = output as HeadObjectOutput;
  withRequestInfo(output2, resp);
  return output2;
}

const toStr = (num?: number) => {
  if (num === undefined) {
    return ''
  }
  return String(num)
}

const makeRangeString = (start?: number, end?: number): string => {
  if (start === undefined && end === undefined) {
    return '';
  }

  if (start !== undefined && end !== undefined && start > end) {
    throw new TosClientError('invalid range format');
  }
  return 'bytes=' + toStr(start) + '-' + toStr(end);
}

export const makeGetObjectHeaders = (input: GetObjectInput) => {
  const headers: Headers = input.RequestHeader ?? {};
  writeHeaders(headers, 'if-match', input.IfMatch);
  if (input.IfModifiedSince) {
    writeHeaders(headers, 'if-modified-since', input.IfModifiedSince.toUTCString());
  }
  writeHeaders(headers, 'If-none-match', input.IfNoneMatch);
  if (input.IfUnmodifiedSince) {
    writeHeaders(headers, 'if-unmodified-since', input.IfUnmodifiedSince.toUTCString());
  }
  writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
  writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
  writeHeaders(headers,'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
  let range = input.Range;
  if (!range) {
    range = makeRangeString(input.RangeStart, input.RangeEnd);
  }
  writeHeaders(headers, 'range', range);
  return headers;
}

export const withGetObjectOutput = (res: Response): GetObjectOutput => {
  const data = res.data as Reader
  const meta = getMeta(res.headers);
  const output: InnerGetObjectBasicOutput = {
    ETag: res.headers['etag'] ?? '',
    ContentRange: res.headers['content-range'],
    LastModified: res.headers['last-modified'] ?  new Date(res.headers['last-modified']) : undefined,
    DeleteMarker: !!res.headers['x-tos-delete-marker'],
    VersionID: res.headers['x-tos-version-id'] ?? '',
    ContentLength: res.headers['content-length'] ? Number(res.headers['content-length']) : 0,
    ContentType: res.headers['content-type'] ?? '',
    CacheControl: res.headers['cache-control'],
    Expires: res.headers['expires'] ? new Date(res.headers['expires']) : undefined,
    ContentDisposition: res.headers['content-disposition'] ? safeDecodeURIComponent(res.headers['content-disposition']) : undefined,
    ContentEncoding: res.headers['content-encoding'],
    ContentLanguage: res.headers['content-language'],
    StorageClass: res.headers['x-tos-storage-class'] as StorageClassType,
    SSECAlgorithm: res.headers['x-tos-server-side-encryption-customer-algorithm'],
    SSECKeyMD5: res.headers['x-tos-server-side-encryption-customer-key-md5'],
    Meta: meta,
    HashCrc64ecma: res.headers['x-tos-hash-crc64ecma']
  }
  const output2 = output as GetObjectOutput;
  withRequestInfo(output2, res);
  output2.Content = data;
  return output2;
}

export interface DeleteObjectInput {
  Bucket: string;
  Key: string;
  VersionID?: string;
}

export const getSortedQueryString = (query: Query) => {
  const newQuery: Record<string, string | number | undefined> = JSON.parse(JSON.stringify(query));
  const searchParts: string[] = [];
  Object.keys(newQuery)
    .sort()
    .forEach((key) => {
      if (newQuery[key] !== undefined) {
        searchParts.push(
          `${encodeURIComponent(key)}=${encodeURIComponent(newQuery[key] as string)}`
        );
      }
    });
  return searchParts.join('&');
};

export const writeHeaders = (headers: Headers, key: string, value: string | number | undefined) => {
  if (value) {
    headers[key] = String(value);
  }
}

export const writeQuery = (query: Query, key: string, value: string | undefined | number) => {
  if (value !== undefined && value !== null) {
    query[key] = value
  }
}

export const isNil = <T>(t: T) => {
  return t === undefined || t === null
}

export const obj2QueryStr = (v?: Record<string, string | undefined>): string => {
  if (!v) {
    return '';
  }
  const res: string[] = []
  Object.keys(v)
    .forEach((key) => {
      if (v[key] === undefined) {
        return;
      }
      const vStr = `${v[key]}`;
      const entityStr = `${encodeURIComponent(key)}=${encodeURIComponent(vStr)}`;
      res.push(entityStr);
    })
  return res.join('&')
}

export const getTotalSize = (content?: SupportObjectBody, contentLength?: number) => {
  if (contentLength !== undefined) {
    return contentLength;
  }
  if (content instanceof ArrayBuffer) {
    return content.byteLength;
  }
  return 0;
}

export const writeMeta = (headers: Headers, meta?: Record<string, string>) => {
  if (!meta) {
    return;
  }
  Object.keys(meta).forEach((metaKey: string) => {
    const metaValue = meta?.[metaKey];
    const value = encodeURIComponent(metaValue)
    const key = encodeURIComponent(`x-tos-meta-${metaKey}`)
    writeHeaders(headers, key, value)
  })
}

export const safeDecodeURIComponent = (str: string) => {
  try {
    const res = decodeURIComponent(str)
    return res
  } catch (e) {
    return str
  }
}

export const getMeta = (headers: Headers) => {
  const meta: Record<string, string> = {};
  Object.keys(headers).forEach((key) => {
    const metaPrefix = 'x-tos-meta-'
    if (key.startsWith(metaPrefix)) {
      const newKey = key.slice(metaPrefix.length);
      if (!newKey) {
        return;
      }
      const metaValue = headers[key];
      meta[safeDecodeURIComponent(newKey)] = safeDecodeURIComponent(metaValue ?? '');
    }
  })
  return meta;
}

export const encodeContentDisposition = (contentDisposition: string): string => {
  const ContentDispositionSep = ";"
  const Quotation = '"'
  const metas = contentDisposition.split(ContentDispositionSep);
  const res: string[] = [];
  for (const meta of metas) {
    const index = meta.indexOf('=');
    if (index < 0) {
      res.push(meta)
    } else {
      const fisrtSubstr = meta.slice(0, index + 1);
      let lastSubstr = meta.slice(index + 1);
      let leftQuotation = '';
      let rightQuotation = '';
      if (lastSubstr.length > 0 && fisrtSubstr.trim().toLowerCase() === 'filename='){
        // 跳过 ""
        if (lastSubstr[0] === Quotation){
          leftQuotation = Quotation
          lastSubstr = lastSubstr.slice(1)
        }
        if (lastSubstr[lastSubstr.length - 1] === Quotation){
          rightQuotation = Quotation;
          lastSubstr = lastSubstr.slice(0, lastSubstr.length - 1)
        }
        res.push(fisrtSubstr + leftQuotation + encodeURIComponent(lastSubstr) + rightQuotation);
      } else {
        res.push(meta)
      }
    }
  }
  return res.join(ContentDispositionSep);
}

interface UserMeta {
  Key: string;
  Value: string;
}

interface RawFetchTask {
  UserMeta?: UserMeta[]
}

export  interface RawGetFetchTaskBody {
  Task: RawFetchTask
}

export const userMeta2Meta = (body?: RawGetFetchTaskBody) => {
  const userMeta = body?.Task.UserMeta;
  const meta: Record<string, string> = {}
  if (!userMeta) {
    return meta;
  }
  userMeta.forEach(item => {
    const key = item.Key;
    const value = item.Value;
    meta[safeDecodeURIComponent(key)] = safeDecodeURIComponent(value)
  })
  return meta;
}
export const encodeChineseCharacters = (str?: string): string => {
  if (!str) {
    return ''
  }
  return str.split('').map((char) => {
    return /[\u0080-\uFFFF]/.test(char) ? encodeURIComponent(char) : char;
  }).join('');
}

export  interface OutputWithSSEC {
  SSECAlgorithm?: string; // 客户自定义密钥的加密方式，可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  SSECKeyMD5?: string;
}

export const withSSEC = (output: OutputWithSSEC, headers?: Headers) => {
  if (!headers) {
    return;
  }

  if (headers['x-tos-server-side-encryption-customer-algorithm']) {
    output.SSECAlgorithm = headers['x-tos-server-side-encryption-customer-algorithm']
  }

  if (headers['x-tos-server-side-encryption-customer-key-md5']) {
    output.SSECKeyMD5 = headers['x-tos-server-side-encryption-customer-key-md5']
  }
}

interface GetDateTimeStrInput {
  date?: Date;
  type?: 'Z' | 'ISO'
}

export const getDateTimeStr = (opt?: GetDateTimeStrInput): string=> {
  const date = opt?.date ?? new Date();
  const type = opt?.type ?? 'Z';
  if (type === 'ISO') {
    return date.toISOString();
  }

  const dateTime =
    date.toISOString().replace(/\..+/, '').replace(/-/g, '').replace(/:/g, '') +
      'Z';

  return dateTime;
}

interface SchemeHost {
  scheme: string;
  host: string;
}

export const getEndpoint = (region: string) => {
  return `tos-${region}.volces.com`;
};

export const schemeHost = (endpoint: string): SchemeHost => {
  let scheme = '';
  let host = '';
  if (endpoint.startsWith('https')) {
    scheme = "https"
    host = endpoint.slice("https://".length);
  } else if (endpoint.startsWith('http')) {
    scheme = "http"
    host = endpoint.slice("http://".length);
  } else  {
    scheme = "https";
    host = endpoint;
  }
  return {
    scheme,
    host,
  }
}

export const normalizeHeadersKey = (
  headers: Headers | undefined
): Headers => {
  if (!headers) {
    return {};
  }
  const headers1: Headers = headers;
  const headers2: Headers = {};
  Object.keys(headers1).forEach((key: string) => {
    if (headers1[key] != null) {
      headers2[key] = headers1[key];
    }
  });

  const headers3: Headers = {};
  Object.keys(headers2).forEach((key: string) => {
    const newKey = key.toLowerCase();
    headers3[newKey] = headers2[key];
  });

  return headers3;
};

export const getSize = (body: SupportObjectBody, headers?: Headers): number | null =>{
  if (body instanceof  ArrayBuffer) {
    return body.byteLength
  };
  if (headers && headers['content-length']) {
    const v = Number(headers['content-length']);
    if (v) {
      return v;
    }
  }

  return null;
}