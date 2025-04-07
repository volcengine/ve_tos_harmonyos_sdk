/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { ACLType, AzRedundancyType,
  MetadataDirectiveType,
  RedirectType,
  StorageClassType, VersioningStatusType, UploadEventType } from './enum';
import { Headers } from './common';
import { stream } from '@kit.ArkTS';
import { InnerGetObjectBasicOutput, InnerHeadObjectOutput } from './inner';
import { DataTransferListener } from './DataTransferListener'
import { rcp } from '@kit.RemoteCommunicationKit';
import { CancelHook } from '../cancel';

export interface GenericInput {
  RequestHeader?: Record<string, string>,
  //RequestQuery?: Record<string, string | number>,
}

export interface RequestInfo {
  StatusCode: number;
  Headers: Headers;

  /**
   * identifies the errored request, equals to headers['x-tos-request-id'].
   * If you has any question about the request, please send the requestId and id2 to TOS worker.
   */
  RequestID: string;

  /**
   * identifies the errored request, equals to headers['x-tos-id-2'].
   * If you has any question about the request, please send the requestId and id2 to TOS worker.
   */
  ID2: string;
}


export interface Owner {
  ID: string
}

export interface ListBucketsInput {
  ProjectName?: string;
}

export interface Bucket {
  // '2021-07-20T09:22:05.000Z'
  CreationDate: string;
  ExtranetEndpoint: string;
  IntranetEndpoint: string;
  Location: string;
  Name: string;
}


export interface ListBucketsOutput extends RequestInfo{
  Owner?: Owner;
  Buckets: Bucket[];
}

export interface CreateBucketInput extends GenericInput {
  Bucket: string;
  ACL?: ACLType;
  GrantFullControl?: string;
  GrantRead?: string;
  GrantReadAcp?: string;
  GrantWrite?: string;
  GrantWriteAcp?: string;
  StorageClass?: StorageClassType;
  AzRedundancy?: AzRedundancyType;
  ProjectName?: string;
}

export  interface  CreateBucketOutput extends RequestInfo {
  Location: string;
}

export interface HeadBucketInput {
  Bucket: string;
}

export interface HeadBucketOutput extends RequestInfo {
  Region: string;
  StorageClass: StorageClassType;
  AzRedundancy: AzRedundancyType;
  ProjectName?:string;
}

export interface DeleteBucketInput {
  Bucket: string;
}

export interface  DeleteBucketOutput extends RequestInfo {}

export interface GetBucketLocationInput {
  Bucket: string;
}

export interface GetBucketLocationRespBody {
  ExtranetEndpoint: string;
  IntranetEndpoint: string;
  Region: string;
}

export interface  GetBucketLocationOutput extends RequestInfo {
  ExtranetEndpoint: string;
  IntranetEndpoint: string;
  Region: string;
}

interface ApplyServerSideEncryptionByDefault {
  // SSEAlgorithm support 'kms' and 'AES256'
  SSEAlgorithm: string;
  KMSMasterKeyID?: string;
}

export interface BucketEncryptionDataRule {
  ApplyServerSideEncryptionByDefault: ApplyServerSideEncryptionByDefault;
}

export interface BucketEncryptionBody {
  Rule: BucketEncryptionDataRule;
}

export interface PutBucketEncryptionInput {
  Bucket: string;
  Rule: BucketEncryptionDataRule;
}

export interface  PutBucketEncryptionOutput extends RequestInfo {}

export interface GetBucketEncryptionInput {
  Bucket: string
}

export interface  GetBucketEncryptionOutput extends RequestInfo {
  Rule: BucketEncryptionDataRule;
}

export interface DeleteBucketEncryptionInput {
  Bucket: string;
}

export interface  DeleteBucketEncryptionOutput extends RequestInfo {}

interface Condition {
  HttpCode: number;
  KeyPrefix?: string;
  KeySuffix?: string;
}

interface MirrorHeader {
  PassAll?: boolean
  Pass?: string[]
  Remove?: string[];
}

interface SourceEndpoint {
  Primary: string[];
  Follower?: string[];
}

interface PublicSource {
  FixedEndpoint?: boolean;
  SourceEndpoint: SourceEndpoint
}

interface ReplaceKeyPrefix {
  KeyPrefix?: string;
  ReplaceWith?: string;
}

export  interface Transform {
  WithKeyPrefix?: string;
  WithKeySuffix?: string;
  ReplaceKeyPrefix?: ReplaceKeyPrefix;
}

export interface Redirect {
  RedirectType?: RedirectType;
  FetchSourceOnRedirect?: boolean;
  PassQuery?: boolean;
  FollowRedirect?: boolean;
  MirrorHeader?: MirrorHeader;
  PublicSource?: PublicSource;
  Transform?: Transform;
  // FetchHeaderToMetaDataRule?: FetchHeaderToMetaDataRule;
}

export interface MirrorBackRule {
  ID: string;
  Condition: Condition;
  Redirect: Redirect;
}

export interface BucketMirrorBackRuleBody {
  Rules: MirrorBackRule[];
}

export interface PutBucketMirrorBackInput {
  Bucket: string;
  Rules: MirrorBackRule[];
}

export interface  PutBucketMirrorBackOutput extends RequestInfo {}

export interface GetBucketMirrorBackInput {
  Bucket: string;
}

export interface  GetBucketMirrorBackOutput extends RequestInfo{
  Rules: MirrorBackRule[];
}

export interface DeleteBucketMirrorBackInput {
  Bucket: string;
}

export interface  DeleteBucketMirrorBackOutput extends RequestInfo {}


export interface PutBucketVersioningInput {
  Bucket: string;
  Status: VersioningStatusType
}

export interface BucketVersioningBody {
  Status: VersioningStatusType
}

export interface PutBucketVersioningOutput extends RequestInfo {}

export interface GetBucketVersioningInput {
  Bucket: string;
}

export interface GetBucketVersioningOutput extends RequestInfo {
  Status: VersioningStatusType
}

export interface PutObjectBasicInput extends GenericInput {
  Bucket: string;
  Key: string;
  ContentMD5?: string;
  ContentSHA256?: string;
  ContentLength?: number;
  CacheControl?: string;
  Expires?: Date,
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  ContentType?: string;
  Meta?: Record<string, string>,
  StorageClass?: StorageClassType,
  ACL?: ACLType,
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
  Callback?: string;
  CallbackVar?: string;
}

export type SupportObjectBody = ArrayBuffer | rcp.UploadFromStream | rcp.UploadFromFile

export interface PutObjectInput extends PutObjectBasicInput {
  Content?: SupportObjectBody
}

export interface  PutObjectOutput extends RequestInfo {
  CallbackResult?: string;
  HashCrc64ecma?: string;
}

export interface PutObjectFromFileInput extends PutObjectBasicInput {
  FilePath: string;
}

export interface PutObjectFromFileOutput extends RequestInfo {
  CallbackResult?: string;
  HashCrc64ecma?: string;
}

export interface UploadPartInfo {
  PartNumber: number
  PartSize: number
  Offset: number
  ETag: string
  HashCrc64ecma: string
}

export interface UploadEvent {
  Type: UploadEventType
  Err?: Error;
  Bucket: string;
  Key: string;
  UploadID: string;
  FilePath: string;
  CheckpointFile?: string;
  UploadPartInfo?: UploadPartInfo
}

export interface UploadEventListener {
  EventChange: (event: UploadEvent) => void;
}

export interface UploadFileInput extends CreateMultipartUploadInput {
  FilePath: string;
  PartSize?: number;
  TaskNum?: number;
  EnableCheckpoint?: boolean;
  CheckpointFile?: string;
  UploadEventListener?: UploadEventListener;
  DataTransferListener?: DataTransferListener;
  CancelHook?: CancelHook;
}

export interface UploadFileOutput extends CompleteMultipartUploadOutput{}

export interface CopyObjectInput extends GenericInput {
  Bucket: string;
  Key: string;
  SrcBucket: string;
  SrcKey: string;
  SrcVersionID?: string;
  CacheControl?: string;
  Expires?: Date,
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  ContentType?: string;
  CopySourceIfMatch?: string
  CopySourceIfModifiedSince?: Date;
  CopySourceIfNoneMatch?: string;
  CopySourceIfUnmodifiedSince?: Date;
  CopySourceSSECAlgorithm?: string // 可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  CopySourceSSECKey?: string
  CopySourceSSECKeyMD5?: string
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
  ACL?: ACLType
  MetadataDirective?: MetadataDirectiveType,
  Meta?: Record<string, string>,
  StorageClass?: StorageClassType,
}

export interface CopyObjectOutput extends RequestInfo {
  ETag: string;
  LastModified?: Date;
  CopySourceVersionID?: string;
  VersionID?: string;
  SSECAlgorithm?: string;
  SSECKeyMD5?: string;
}

export interface ListObjectsType2Input {
  Bucket: string // required
  Prefix?: string
  Delimiter?: string
  StartAfter?: string
  ContinuationToken?: string
  MaxKeys?: number;
  EncodingType?: string
  ListOnlyOnce?: boolean
}

export interface ListedCommonPrefix {
  Prefix: string;
}

export interface ListedObject {
  ETag: string;
  Key: string;

  // "2021-08-02T09:53:27.000Z"
  LastModified: string;
  Owner?: Owner;
  Size: number;
  StorageClass: string;
  HashCrc64ecma?: string;
}

export interface ListObjectsType2Output extends RequestInfo {
  Name: string;
  Prefix?: string;
  MaxKeys: number;
  Delimiter?: string;
  EncodingType?: string;
  IsTruncated: boolean;
  KeyCount: number;
  StartAfter?: string;
  ContinuationToken?: string;
  NextContinuationToken?: string;
  CommonPrefixes: ListedCommonPrefix[];
  Contents: ListedObject[];
}

export interface ListObjectVersionsInput {
  Bucket: string // required
  Prefix?: string
  Delimiter?: string
  KeyMarker?: string
  VersionIDMarker?: string
  MaxKeys?: number;
  EncodingType?: string
}

export interface ListObjectsVersionItem {
  ETag: string;
  IsLatest: boolean;
  Key: string;
  LastModified: string;
  Owner: Owner;
  Size: number;
  StorageClass: string;
  VersionId: string;
  HashCrc64ecma?: string;
}

export interface ListObjectDeleteMarkerItem {
  ETag: string;
  IsLatest: boolean;
  Key: string;
  LastModified: string;
  Owner: Owner;
  Size: number;
  StorageClass: string;
  VersionId: string;
}

export interface ListObjectVersionsOutput extends RequestInfo {
  Name: string;
  Prefix: string;
  KeyMarker?: string;
  VersionIdMarker?: string;
  MaxKeys: number;
  Delimiter?: string;
  IsTruncated: boolean;
  EncodingType?: string;
  NextKeyMarker?: string;
  NextVersionIdMarker?: string;
  CommonPrefixes: ListedCommonPrefix[];
  Versions: ListObjectsVersionItem[];
  DeleteMarkers: ListObjectDeleteMarkerItem[];
}

export class ObjectTobeDeleted {
  Key: string;
  VersionID?: string;

  constructor(Key: string, VersionID?: string) {
    this.Key = Key;
    this.VersionID = VersionID
  }
}

export interface DeleteMultiObjectsBody {
  Objects: ObjectTobeDeleted[] // required，no empty
  Quiet?: boolean
}

export interface DeleteMultiObjectsInput {
  Bucket: string // required
  Objects: ObjectTobeDeleted[] // required，no empty
  Quiet?: boolean
}

export interface Deleted {
  Key: string;
  VersionId: string;
  DeleteMarker?: boolean;
  DeleteMarkerVersionId?: string;
}

export interface DeleteError {
  Code: string;
  Message: string;
  Key: string;
  VersionId: string;
}

export interface DeleteMultiObjectsOutput extends RequestInfo {
  Deleted: Deleted[];
  Error: DeleteError[];
}

export class Reader {
  close: () => void
  read: (maxBytesToRead: number) => ArrayBuffer;

  constructor(read: (maxBytesToRead: number) => ArrayBuffer, close: () => void) {
    this.read = read;
    this.close = close;
  }
}

export interface GetObjectInput extends GenericInput{
  Bucket: string;
  Key: string;
  VersionId?: string;
  IfMatch?: string;
  IfModifiedSince?: Date;
  IfNoneMatch?: string;
  IfUnmodifiedSince?: Date;
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
  RangeStart?: number;
  RangeEnd?: number;
  Range?: string;
}


export interface GetObjectBasicOutput extends RequestInfo, InnerGetObjectBasicOutput {}

export interface GetObjectOutput extends GetObjectBasicOutput {
  Content: Reader;
}

// export interface GetObjectToFileInput extends GetObjectInput {
//   FilePath: string
// }
//
// export interface GetObjectToFileOutput extends GetObjectBasicOutput {}

export interface HeadObjectInput {
  Bucket: string // required
  Key: string // required
  VersionID?: string
  IfMatch?: string;
  IfModifiedSince?: Date;
  IfNoneMatch?: string;
  IfUnmodifiedSince?: Date;
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
}

export interface HeadObjectOutput extends RequestInfo, InnerHeadObjectOutput {}

export interface DownloadFileInput extends HeadObjectInput {
  FilePath: string;
  PartSize?: number;
  TaskNum?: number;
  EnableCheckpoint?: boolean;
  CheckpointFile?: string;
  DataTransferListener?: DataTransferListener;
  CancelHook?: CancelHook;
}

export interface DownloadFileOutput extends HeadObjectOutput {}

export interface DeleteObjectInput {
  Bucket: string;
  Key: string;
  VersionID?: string;
}

export interface  DeleteObjectOutput extends RequestInfo {
  DeleteMarker: boolean;
  VersionID?: string;
}

export interface SetObjectMetaInput extends GenericInput{
  Bucket: string;
  Key: string;
  VersionId?: string;
  CacheControl?: string;
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  ContentType?: string;
  Expires?: Date;
  Meta?: Record<string, string>,
}

export interface SetObjectMetaOutput extends RequestInfo {}

export interface AppendObjectInput extends GenericInput{
  Bucket: string // required
  Key: string    // required
  Offset: number  // required
  Content: SupportObjectBody // required
  ContentLength?: number;
  CacheControl?: string;
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  ContentType?: string;
  Expires?: Date,
  ACL?: ACLType
  Meta?: Record<string, string>,
  // StorageClass?: StorageClassType,
}

export interface AppendObjectOutput extends RequestInfo {
  NextAppendOffset: number
  HashCrc64ecma?: string;
}

export interface FetchObjectInput extends GenericInput{
  Bucket: string;
  Key: string;
  URL: string;
  ACL?: ACLType;
  StorageClass?: StorageClassType;
  SSECAlgorithm?: string; // 客户自定义密钥的加密方式，可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  SSECKey?: string;
  SSECKeyMD5?: string;
  Meta?: Record<string, string> // TOS SDK 会对 Key/Value 包含的中文汉字进行 URL 编码
  IgnoreSameKey?: boolean;
  ContentMD5?: string;
}

export interface FetchObjectOutput extends RequestInfo {
  VersionID?: string;
  ETag: string;
  SSECAlgorithm?: string;
  SSECKeyMD5?: string;
}

export interface PutFetchTaskBody {
  URL: string,
  Object: string,
  IgnoreSameKey?: boolean,
  ContentMD5?: string
}

export interface PutFetchTaskInput extends GenericInput{
  Bucket: string // required
  Key: string // required
  URL: string;
  IgnoreSameKey?: boolean;
  ContentMD5?: string;
  ACL?: ACLType;
  StorageClass?: StorageClassType;
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
  Meta?: Record<string, string> // TOS SDK 会对 Key/Value 包含的中文汉字进行 URL 编码
}

export interface PutFetchTaskOutput extends RequestInfo {
  TaskId: string
}

export interface GetFetchTaskInput {
  Bucket: string // required
  TaskID: string // required
}

export interface FetchTask {
  URL: string
  IgnoreSameKey?: boolean;
  Bucket: string
  Object: string
  ContentMD5?: string;
  ACL?: ACLType;
  StorageClass?: StorageClassType;
  SSECAlgorithm?: string;
  SSECKey?: string;
  SSECKeyMD5?: string;
  Meta?: Record<string, string>
}

export interface GetFetchTaskOutput extends RequestInfo {
  State: string
  Err: string
  Task: FetchTask
}

export interface PreSignedURLInput {
  Bucket?: string;
  Key: string;

  /**
   * default: 'GET'
   */
  HttpMethod?: 'GET' | 'PUT';

  /**
   * unit: second, default: 1800
   */
  Expires?: number;
  AlternativeEndpoint?: string;
  Query?: Record<string, string>;
  IsCustomDomain?: boolean;
}

export interface PreSignedURLOutput {
  SignedUrl: string // 预签名 URL
}

export interface GetSignatureQueryInput {
  bucket: string;
  method: 'GET' | 'PUT';
  path: string;
  subdomain: boolean;
  endpoint: string;

  // unit: second
  expires: number;
  query?: Record<string, string | undefined>;
}

export interface PolicySignatureCondition {
  Key: string;
  Value: string;
  Operator: string;
}

export interface PreSignedPolicyURLInput {
  Bucket?: string;
  Expires?: number;
  Conditions: PolicySignatureCondition[];
  AlternativeEndpoint?: string;
  IsCustomDomain?: boolean;
}

export type GetSignedURLForList = (additionalQuery?: Record<string, string>) => string

export type GetSignedURLForGetOrHead = (key: string, additionalQuery?: Record<string, string>) => string

export interface PreSignedPolicyURLGenerator {
  GetSignedURLForList: GetSignedURLForList
  GetSignedURLForGetOrHead: GetSignedURLForGetOrHead
}

export interface PreSignedPolicyURLOutput extends PreSignedPolicyURLGenerator {
  SignedQuery: string;
}

export interface PostSignatureCondition {
  Key: string
  Value: string
  Operator?: string
}

export interface PreSignedPostSignatureInput {
  Bucket: string;
  Key: string;
  // unit: seconds, default: 3600(1 hour)
  Expires?: number;
  //Fields?: Record<string, string>;
  Conditions?: PostSignatureCondition[];
}

export interface  PreSignedPostSignatureOutput {
  OriginPolicy: string // 签名前的 policy
  Policy:       string // 签名后的 policy，用于表单域 policy，需要 UTF-8 Base64 编码
  Algorithm:    string // 用于表单域 x-tos-algorithm
  Credential:   string // 用于表单域 x-tos-credential
  Date:         string // 用于表单域 x-tos-date
  Signature:    string // 用于表单域 x-tos-signature
}

export interface CreateMultipartUploadInput extends GenericInput{
  Bucket: string; // required
  Key: string; // required
  EncodingType?: string;
  CacheControl?: string;
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  ContentType?: string;
  Expires?: Date;
  ACL?: ACLType;
  SSECAlgorithm?: string; // 客户自定义密钥的加密方式，可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  SSECKey?: string;
  SSECKeyMD5?: string;
  StorageClass?: StorageClassType;
  Meta?: Record<string, string>
}

export interface CreateMultipartUploadOutput extends RequestInfo {
  Bucket: string; // required
  Key: string; // required
  UploadId: string;

  // EncodingType?: string;
  SSECAlgorithm?: string; // 客户自定义密钥的加密方式，可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  SSECKeyMD5?: string;
}

export interface ListMultipartUploadsInput {
  Bucket: string // required
  Prefix?: string
  Delimiter?: string
  KeyMarker?: string
  UploadIdMarker?: string
  MaxUploads?: number
  EncodingType?: string
}

export interface ListedUpload {
  Key: string
  UploadId: string
  Owner?: Owner
  StorageClass: StorageClassType
  Initiated: Date
}

export interface ListMultipartUploadsOutput {
  Bucket: string
  Prefix ?: string
  KeyMarker?: string
  UploadIdMarker?: string
  MaxUploads?: number
  Delimiter?: string
  IsTruncated?: boolean
  EncodingType?: string
  NextKeyMarker?: string
  NextUploadIdMarker?: string
  CommonPrefixes: ListedCommonPrefix[]
  Uploads: ListedUpload[]
}

export interface AbortMultipartUploadInput {
  Bucket: string // required
  Key: string // required
  UploadID: string // required
}

export interface AbortMultipartUploadOutput extends RequestInfo {}

export interface UploadPartBasicInput extends GenericInput{
  Bucket: string // required
  Key: string    // required
  UploadID: string  // required
  PartNumber: number // required
  ContentMD5?: string;
  SSECAlgorithm?: string // 客户自定义密钥的加密方式，可扩展，不定义为枚举，当前只支持 AES256，TOS SDK 会做强校验
  SSECKey?: string
  SSECKeyMD5?: string
  DataTransferListener?: DataTransferListener
}

export interface UploadPartInput extends UploadPartBasicInput {
  Content: SupportObjectBody
}

export interface UploadPartOutput extends RequestInfo {
  PartNumber: number;
  ETag: string;
  //SSECAlgorithm: string // 可扩展，不定义为枚举
  //SSECKeyMD5: string
  HashCrc64ecma?: string;
}

export  class UploadedPart {
  PartNumber: number;
  ETag: string;
  Size?: number;
  LastModified?: Date;

  constructor(PartNumber: number, ETag: string) {
    this.PartNumber = PartNumber;
    this.ETag = ETag;
  }
}

export interface CompleteMultipartUploadInput {
  Bucket: string // required
  Key: string    // required
  UploadID: string  // required
  Parts?: UploadedPart[] // opt
  CompleteAll?: boolean;
  Callback?: string;
  CallbackVar?:  string;
}

export interface CompleteMultipartUploadOutput extends RequestInfo{
  Bucket: string
  Key: string
  ETag: string
  Location: string
  VersionID?: string
  CompletedParts?: UploadedPart[];
  CallbackResult?: string;
  HashCrc64ecma?: string;
}

export interface ListPartsInput {
  Bucket:           string // required
  Key:              string // required
  UploadId:         string // required
  PartNumberMarker?: number
  MaxParts?: number
}

export interface ListPartsOutput extends RequestInfo {
  Bucket:           string
  Key:              string
  UploadId:         string
  PartNumberMarker: number
  MaxParts: number
  IsTruncated?: boolean
  NextPartNumberMarker?: number
  StorageClass: StorageClassType
  Owner:Owner
  Parts: UploadedPart[]
}

export interface UploadPartCopyInput extends GenericInput {
  Bucket: string  // required
  Key: string    // required
  UploadID: string  // required
  PartNumber: number // required
  SrcBucket: string // required
  SrcKey: string   // required， 拼接成 x-tos-copy-source 头域时，需要对 SrcKey 做 urlencode without '/' 处理
  SrcVersionID?: string
  CopySourceRangeStart?: number;
  CopySourceRangeEnd?: number;
  CopySourceRange?: string;
}

export interface UploadPartCopyOutput extends RequestInfo {
  ETag: string;
  LastModified: Date;
  SSECAlgorithm?: string;
  SSECKeyMD5?: string;
}

