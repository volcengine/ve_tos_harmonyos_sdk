/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { rcp } from '@kit.RemoteCommunicationKit';
import { makeAxiosInst } from './axios';
import { Headers, Query, Method, Response, Any } from './types/common'
import { ISigV4Credentials, SignersV4 } from './signatureV4';
import { getEndpoint, getSortedQueryString, schemeHost } from './utils/common';
import { hashMd5, stringify } from './crypto';
import { buffer, stream } from '@kit.ArkTS';
import { TosServerErrorData } from './TosServerError';
import { TosServerError } from './TosServerError';
import { TosClientError } from './TosClientError';
import { Reader } from './types/model2';
import { VERSION } from './version';
import { http } from '@kit.NetworkKit';

export interface TOSConstructorOptions {
  accessKeyId: string;
  accessKeySecret: string;
  securityToken?: string;
  endpoint?: string;
  region: string
  isCustomDomain?: boolean;
  connectionTimeout?: number;
  requestTimeout?: number;
}

export interface FetchOpts {
  needMd5?: boolean;
  subdomainBucket?: string;
  axiosOpts?: AxiosRequestConfig;
  isStreamResp?: boolean;
  isStreamReq?: boolean;
  useCustomHttp?: boolean;
  onProgress?: (size: number) => void
  onDataReceive?: (incomingData: ArrayBuffer) => Promise<void | number>;
}

interface FetchObjectInput {
  bucket?: string;
  key: string
}

interface WriteStreamRequestInput {
  baseURL: string;
  path: string;
  method: Method;
  query: Query;
  headers: Headers;
  body: rcp.UploadFromStream | ArrayBuffer,
}

export class TOSBase {
  protected opts: TOSConstructorOptions = { accessKeyId: '', accessKeySecret: '', region: '', endpoint: '' }
  private axiosInst: AxiosInstance = axios.create();
  protected scheme: string;

  constructor(_opts: TOSConstructorOptions) {
    this.opts = _opts;
    const schemeHostRes = schemeHost(_opts.endpoint ? _opts.endpoint : getEndpoint(_opts.region));
    this.scheme = schemeHostRes.scheme;
    this.opts.endpoint = schemeHostRes.host;
    this.axiosInst = axios.create({
      timeout: this.opts.requestTimeout,
      connectTimeout: this.opts.connectionTimeout
    });
  }

  private getUserAgent = () => {
    return `tos-ArkTS-sdk/${VERSION}`
  }

  private handleRcpError = (url: string, response: rcp.Response, session: rcp.Session) => {
    if (response.headers['x-tos-request-id']) {
      const data = response.body
      const res = data ? stringify(new Uint8Array(data), 'utf-8') : '';
      let respData: TosServerErrorData = {};
      try {
        if (res) {
          respData = JSON.parse(res);
        }
      } catch (e) {
        console.log(e);
        respData = {};
      }
      const err = new TosServerError(url, response.statusCode, response.headers as Headers, respData)
      session.close();
      throw err;
    }
    session.close();
    throw new TosClientError('network error')
  }

  private createRcpSession = () => {
    return rcp.createSession({
      requestConfiguration: {
        transfer: {
          timeout: {
            connectMs: this.opts.connectionTimeout,
            transferMs: this.opts.requestTimeout,
          },
        },
      }
    });
  }

  private writeStreamRequest = async (input: WriteStreamRequestInput) => {
    const body = input.body;
    const url = input.baseURL + input.path + '?' + getSortedQueryString(input.query)
    const request = new rcp.Request(url, input.method, input.headers, body);
    const session = this.createRcpSession();
    let response: rcp.Response;
    try {
      response = await session.fetch(request)
    } catch (e) {
      session.close();
      throw new TosClientError('session fetch error', e);
    }

    if (response.statusCode >= 300) {
      this.handleRcpError(input.baseURL + input.path, response, session);
    }
    let resBody: Any = {};
    try {
      if(response.body) {
        const tmpStr = stringify(new Uint8Array(response.body), 'utf-8');
        if (tmpStr) {
          resBody = JSON.parse(tmpStr)
        }
      }
    } catch (e) {
      console.log(e);
    }
    session.close();
    return new Response(response.statusCode, response.headers as Headers, resBody)
  }

  protected async fetch(
    method: Method,
    path: string,
    query: Query,
    headers: Headers,
    body?: Object,
    opts?: FetchOpts
  ): Promise<Response> {
    const needMd5 = opts?.needMd5 || false;

    if (body && needMd5) {
      const md5String = hashMd5(JSON.stringify(body), 'base64');
      headers['content-md5'] = md5String as string;
    }

    const arr = (() => {
      // if isCustomDomain true, not add subdomainBucket
      if (opts?.subdomainBucket && !this.opts.isCustomDomain) {
        // endpoint is ip address
        if (this.opts.endpoint && /^(\d|:)/.test(this.opts.endpoint)) {
          return [this.opts.endpoint, `/${opts.subdomainBucket}${path}`];
        }
        return [`${opts?.subdomainBucket}.${this.opts.endpoint}`, path];
      }
      return [this.opts.endpoint, path];
    })();
    const endpoint = arr[0];
    path = arr[1] as string;

    const signv4 = new ISigV4Credentials(
      this.opts.securityToken,
      this.opts.accessKeySecret,
      this.opts.accessKeyId
    );
    const sig = new SignersV4(
      {
        algorithm: 'TOS4-HMAC-SHA256',
        region: this.opts.region,
        serviceName: 'tos',
        bucket: '',
        securityToken: this.opts.securityToken,
      },
      signv4
    );
    //
    const signatureHeaders = sig.signatureHeader({
      endpoints: undefined,
      bucket: '',

      method,
      headers: JSON.parse(JSON.stringify(headers)) as Headers,
      path,
      query: getSortedQueryString(query),
      host: endpoint,
    });

    const baseURL = `${this.scheme}://${endpoint}`;
    const reqOpts: AxiosRequestConfig = {
      method,
      baseURL,
      url: path,
      params: query,
      headers,
      data: body,
    };

    signatureHeaders.forEach((value, key) => {
      if (reqOpts.headers) {
        reqOpts.headers[key] = value;
      }
    });
    if (opts?.isStreamReq) {
      return await this.writeStreamRequest({
        baseURL,
        path,
        method,
        query,
        headers,
        body: body as ArrayBuffer | rcp.UploadFromStream,
      })
    }

    if (opts?.isStreamResp) {
      const NetworkOutputQueue = rcp.NetworkOutputQueue;
      const session = this.createRcpSession();
      const networkOutputQueue = new NetworkOutputQueue();
      const url = baseURL + path + '?' + getSortedQueryString(query)
      const request = new rcp.Request(url, method, headers);
      request.destination = networkOutputQueue;

      // todo 确认一下
      const reader = new Reader((maxBytesToRead: number) => {
        return networkOutputQueue.read(maxBytesToRead);
      }, () => {
        session.close();
      })
      const response = await session.fetch(request)
      if (response.statusCode >= 300) {
        this.handleRcpError(baseURL + path, response, session);
      }
      return new Response(response.statusCode, response.headers as Headers, reader as Any)
    }

    if (reqOpts.headers && !reqOpts.headers['user-agent'] ) {
      reqOpts.headers['user-agent'] = this.getUserAgent();
    }

    if (opts?.onDataReceive) {
      const session = this.createRcpSession();
      const streamData: rcp.WriteStream = {
        write(buffer: ArrayBuffer): Promise<void | number> {
          return opts.onDataReceive?.(buffer) || Promise.resolve();
        }
      };

      let downloadToStream: rcp.DownloadToStream = {
        kind: 'stream',
        stream: streamData
      }
      const url = baseURL + path + '?' + getSortedQueryString(query)
      const request = new rcp.Request(url, method, headers);
      request.destination = downloadToStream;
      let response: rcp.Response;
      try {
        response = await session.fetch(request)
      } catch (e) {
        session.close();
        throw e as Error;
      }
      if (response.statusCode >= 300) {
        this.handleRcpError(baseURL + path, response, session);
      }
      session.close();
      return new Response(response.statusCode, response.headers as Headers, streamData as Any)
    }

    if (opts?.useCustomHttp) {
      return new Promise<Response>((rs, rj) => {
        const httpRequest = http.createHttp();
        let url = (reqOpts.baseURL || '') + (reqOpts.url || '');
        const queryStr = getSortedQueryString(query);
        if (queryStr) {
          url = url + '?' + getSortedQueryString(query);
        }
        httpRequest.request(url, {
          method: reqOpts.method as http.RequestMethod,
          header: reqOpts.headers,
          extraData: body,
        }, (err, res) => {
          if (!err) {
            if (res.responseCode < 400) {
              rs(new Response(res.responseCode, res.header as Headers, res.result as Any))
            } else {
              let result = res.result;
              if (typeof res.result === 'string') {
                try {
                  result = JSON.parse(res.result)
                } catch (e) {}
              }
              rj(new TosServerError(url, res.responseCode as number, res.header as Headers, result as object))
            }
          } else {
            rj(err);
          }
          httpRequest.off("dataSendProgress")
          httpRequest.destroy();
        })


        httpRequest.on("dataSendProgress", (data: http.DataSendProgressInfo) => {
          opts?.onProgress?.(data.sendSize);
        });
      })
    }
    try {
      const res = await this.axiosInst.request<Object, AxiosResponse<Object, Object>, null>({
        method: reqOpts.method,
        baseURL: reqOpts.baseURL,
        url: reqOpts.url,
        params: reqOpts.params,
        headers: reqOpts.headers,
        data: reqOpts.data,
      });

      return new Response(res.status, res.headers as Headers, res.data as Any);
    } catch (err) {
      if (
        axios.isAxiosError(err) && err.response?.headers?.['x-tos-request-id']
      ) {
        // it's ServerError only if `RequestId` exists
        const response: AxiosResponse<TosServerErrorData> = err.response;
        const err2 = new TosServerError(baseURL + path , response.status ?? 404, response.headers as Headers, response.data);
        throw err2;
      }

      // it is neither ServerError nor ClientError, it's other error
      throw new Error(err);
    }
  }

  protected  async fetchBucket(
    bucket: string | undefined,
    method: Method,
    query: Query,
    headers: Headers,
    body?: Object,
    opts?: FetchOpts
  ): Promise<Response> {
    if (!bucket) {
      throw Error('Must provide bucket param');
    }

    const newOpts: FetchOpts = opts ? opts : {};
    newOpts.subdomainBucket = bucket;

    return this.fetch(method, '/', query, headers, body, newOpts);
  }

  protected async _fetchObject(
    input: FetchObjectInput,
    method: Method,
    query: Query,
    headers: Headers,
    body?: Object | buffer.Blob,
    opts?: FetchOpts
  ): Promise<Response> {
    const bucket = input.bucket;
    const actualKey = input.key;
    if (!bucket) {
      throw new TosClientError('Must provide bucket param');
    }

    const newOpts: FetchOpts = opts ? opts : {};
    newOpts.subdomainBucket = bucket;

    return this.fetch(
      method,
      `/${encodeURIComponent(actualKey)}`,
      query,
      headers,
      body,
      newOpts,
    );
  }
}