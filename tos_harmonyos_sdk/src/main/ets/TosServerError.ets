/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { AxiosResponse } from '@ohos/axios';
import { Headers } from './types/common';

export interface TosServerErrorData {
  Code?: string;
  HostId?: string;
  Message?: string;
  RequestId?: string;
  EC?: string;
}

export class TosServerError extends Error {
  // RequsetInfo
  public StatusCode: number;
  public Headers: Headers;

  /**
   * identifies the errored request, equals to headers['x-tos-request-id'].
   * If you has any question about the request, please send the requestId and id2 to TOS worker.
   */
  public RequestID: string;

  /**
   * identifies the errored request, equals to headers['x-tos-id-2'].
   * If you has any question about the request, please send the requestId and id2 to TOS worker.
   */
  public  ID2: string;

  // Common Error
  public Message: string;
  public RequestUrl: string;

  /**
   * is original from backend, equals `data.Code`
   */
  public Code: string;
  public HostID: string;


  constructor(url: string, statusCode: number ,headers?: Headers, data?: TosServerErrorData) {
    super(data?.Message);
    this.RequestUrl = url
    this.Message = data?.Message ?? '';
    this.HostID = data?.HostId ?? '';
    this.Code = data?.Code ?? '';
    this.StatusCode = statusCode;
    this.Headers = headers ?? {};
    this.RequestID = headers?.['x-tos-request-id'] ?? '';
    this.ID2 = headers?.['x-tos-id-2'] ?? '';
  }
}

export default TosServerError;

export enum TosServerCode {
  NoSuchBucket = 'NoSuchBucket',
  NoSuchKey = 'NoSuchKey',
  AccessDenied = 'AccessDenied',
  MalformedAcl = 'MalformedAclError',
  UnexpectedContent = 'UnexpectedContent',
  InvalidRequest = 'InvalidRequest',
  MissingSecurityHeader = 'MissingSecurityHeader',
  InvalidArgument = 'InvalidArgument',
  EntityTooSmall = 'EntityTooSmall',
  InvalidBucketName = 'InvalidBucketName',
  BucketNotEmpty = 'BucketNotEmpty',
  TooManyBuckets = 'TooManyBuckets',
  BucketAlreadyExists = 'BucketAlreadyExists',
  MalformedBody = 'MalformedBody',
  NoSuchLifecycleConfiguration = 'NoSuchLifecycleConfiguration',
  ReplicationConfigurationNotFound = 'ReplicationConfigurationNotFoundError',
  InvalidLocationConstraint = 'InvalidLocationConstraint',
  AuthorizationQueryParametersError = 'AuthorizationQueryParametersError',
  RequestTimeTooSkewed = 'RequestTimeTooSkewed',
  SignatureDoesNotMatch = 'SignatureDoesNotMatch',
  RequestedRangeNotSatisfiable = 'Requested Range Not Satisfiable',
  PreconditionFailed = 'PreconditionFailed',
  BadDigest = 'BadDigest',
  InvalidDigest = 'InvalidDigest',
  EntityTooLarge = 'EntityTooLarge',
  UnImplemented = 'UnImplemented',
  MethodNotAllowed = 'MethodNotAllowed',
  InvalidAccessKeyId = 'InvalidAccessKeyId',
  InvalidSecurityToken = 'InvalidSecurityToken',
  ContentSHA256Mismatch = 'ContentSHA256Mismatch',
  ExceedQPSLimit = 'ExceedQPSLimit',
  ExceedRateLimit = 'ExceedRateLimit',
  NoSuchCORSConfiguration = 'NoSuchCORSConfiguration',
  NoSuchMirrorConfiguration = 'NoSuchMirrorConfiguration',
  NoSuchWebsiteConfiguration = 'NoSuchWebsiteConfiguration',
  MissingRequestBody = 'MissingRequestBodyError',
  BucketAlreadyOwnedByYou = 'BucketAlreadyOwnedByYou',
  NoSuchBucketPolicy = 'NoSuchBucketPolicy',
  PolicyTooLarge = 'PolicyTooLarge',
  MalformedPolicy = 'MalformedPolicy',
  InvalidKey = 'InvalidKey',
  MirrorFailed = 'MirrorFailed',
  Timeout = 'Timeout',
  OffsetNotMatched = 'OffsetNotMatched',
  NotAppendable = 'NotAppendable',
  ContextCanceled = 'ContextCanceled',
  InternalError = 'InternalError',
  TooManyRequests = 'TooManyRequests',
  TimeOut = 'TimeOut',
  ConcurrencyUpdateObjectLimit = 'ConcurrencyUpdateObjectLimit',
  DuplicateUpload = 'DuplicateUpload',
  DuplicateObject = 'DuplicateObject',
  InvalidVersionId = 'InvalidVersionId',
  StorageClassNotMatch = 'StorageClassNotMatch',
  UploadStatusNotUploading = 'UploadStatusNotUploading',
  PartSizeNotMatch = 'PartSizeNotMatch',
  NoUploadPart = 'NoUploadPart',
  PartsLenInvalid = 'PartsLenInvalid',
  PartsIdxSmall = 'PartsIdxSmall',
  PartSizeSmall = 'PartSizeSmall',
  PrefixNotNextKeyPrefix = 'PrefixNotNextKeyPrefix',
  InvalidPart = 'InvalidPart',
  InvalidPartOffset = 'InvalidPartOffset',
  MismatchObject = 'MismatchObject',
  UploadStatusMismatch = 'UploadStatusMismatch',
  CompletingStatusNoExpiration = 'CompletingStatusNoExpiration',
  Found = 'Found',
  InvalidRedirectLocation = 'InvalidRedirectLocation',
}
