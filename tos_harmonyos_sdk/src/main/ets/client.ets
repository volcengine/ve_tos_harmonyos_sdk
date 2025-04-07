/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { TOSBase, TOSConstructorOptions } from './base';
import { hashMd5, hmacSha256ToStr, hmacSha256ToUint8Array, parse, stringify } from './crypto';
import {
  ListBucketsInput,
  ListBucketsOutput,
  CreateBucketInput,
  CreateBucketOutput,
  HeadBucketInput,
  HeadBucketOutput,
  DeleteBucketInput,
  DeleteBucketOutput,
  GetBucketLocationInput,
  GetBucketLocationOutput,
  DeleteBucketEncryptionInput,
  DeleteBucketEncryptionOutput,
  GetBucketEncryptionInput,
  GetBucketEncryptionOutput,
  PutBucketEncryptionInput,
  PutBucketEncryptionOutput,
  PutBucketMirrorBackInput,
  PutBucketMirrorBackOutput,
  BucketMirrorBackRuleBody,
  GetBucketMirrorBackInput,
  DeleteBucketMirrorBackInput,
  GetBucketMirrorBackOutput,
  DeleteBucketMirrorBackOutput,
  AbortMultipartUploadInput,
  AbortMultipartUploadOutput,
  AppendObjectInput,
  AppendObjectOutput,
  BucketVersioningBody,
  CompleteMultipartUploadInput,
  CompleteMultipartUploadOutput,
  CopyObjectInput,
  CopyObjectOutput,
  CreateMultipartUploadInput,
  CreateMultipartUploadOutput,
  DeleteMultiObjectsBody,
  DeleteMultiObjectsInput,
  DeleteMultiObjectsOutput,
  FetchObjectInput,
  FetchObjectOutput,
  GetBucketVersioningInput,
  GetBucketVersioningOutput,
  GetFetchTaskInput,
  GetFetchTaskOutput,
  PutObjectInput,
  PutObjectOutput,
  GetObjectInput,
  GetSignatureQueryInput,
  GetSignedURLForGetOrHead,
  GetSignedURLForList,
  HeadObjectInput,
  HeadObjectOutput,
  ListMultipartUploadsInput,
  ListMultipartUploadsOutput,
  ListObjectsType2Input,
  ListObjectsType2Output,
  ListObjectVersionsInput,
  ListObjectVersionsOutput,
  DeleteObjectInput,
  DeleteObjectOutput,
  ListPartsInput,
  ListPartsOutput,
  PolicySignatureCondition,
  PreSignedPolicyURLInput,
  PreSignedPolicyURLOutput,
  PreSignedPostSignatureInput,
  PreSignedPostSignatureOutput,
  PreSignedURLInput,
  PreSignedURLOutput,
  PutBucketVersioningInput,
  PutBucketVersioningOutput,
  PutFetchTaskBody,
  PutFetchTaskInput,
  PutFetchTaskOutput,
  PutObjectFromFileInput,
  PutObjectFromFileOutput,
  SetObjectMetaInput,
  SetObjectMetaOutput,
  UploadPartInput,
  UploadPartOutput,
  UploadPartCopyOutput,
  UploadPartCopyInput,
  Reader,
  GetObjectOutput,
  UploadFileInput,
  UploadFileOutput,
  UploadedPart,
  UploadEvent,
  UploadPartInfo,
  DownloadFileInput
} from './types/model2'
import { CheckpointRecord, CheckpointRecordPart,
  DownloadFileCheckpointRecord,
  DownloadFileCheckpointRecordPartInfo,
  DownloadFileCheckpointRichInfo,
  InnerGetObjectOutput,
  Task } from './types/inner'
import TosClientError from './TosClientError';
import { Any, Headers, Part, PartBody, Query, Response } from './types/common';
import { ListBucketsRequestHeaders } from './types/headers';
import {
  getDateTimeStr,
  isNil, 
  obj2QueryStr,
  OutputWithSSEC,
  RawGetFetchTaskBody,
  userMeta2Meta,
  withSSEC,
  writeHeaders,
  writeMeta,
  writeQuery,
  withCopyObjectOutput,
  withHeadObjectOutput,
  withRequestInfo,
  getMeta,
  makeGetObjectHeaders,
  withGetObjectOutput,
  schemeHost,
  encodeContentDisposition,
  normalizeHeadersKey,
  getSize
} from './utils/common'
import { AzRedundancyType, StorageClassType, VersioningStatusType, UploadEventType } from './types/enum';
import { ISigV4Credentials, SignersV4 } from './signatureV4';
import { fileIo as fs } from '@kit.CoreFileKit';
import { rcp } from '@kit.RemoteCommunicationKit'
import { calculateSafePartSize, getAllTasks, getDirName, isDirectory, parseCheckpointRecord } from './utils/uploadFile';
import TosServerError from './TosServerError';
import { DataTransferType } from './types/DataTransferListener';
import { buffer } from '@kit.ArkTS';
import { CancelError } from './cancel';

export const DEFAULT_PART_SIZE = 20 * 1024 * 1024; // 20 MB

export class TosClient extends TOSBase {
  private DefaultListMaxKeys = 1000;

  constructor(opts: TOSConstructorOptions) {
    super(opts);
  }

  listBuckets = async (input?: ListBucketsInput): Promise<ListBucketsOutput> => {
    const headers: ListBucketsRequestHeaders = {};
    if (input?.ProjectName) {
      headers['x-tos-project-name'] = input.ProjectName;
    }
    const res = await this.fetch('GET', '/', {}, headers)
    const output = res.data as ListBucketsOutput;
    if (!output.Buckets) {
      output.Buckets = []
    }
    withRequestInfo(output, res);
    return output;
  }
  createBucket = async (input: CreateBucketInput): Promise<CreateBucketOutput> => {
    const bucketName = input.Bucket;
    if (bucketName.length < 3 || bucketName.length > 63) {
      throw new TosClientError(
        'invalid bucket name, the length must be [3, 63]'
      );
    }
    if (!/^([a-z]|-|\d)+$/.test(bucketName)) {
      throw new TosClientError(
        'invalid bucket name, the character set is illegal'
      );
    }
    if (/^-/.test(bucketName) || /-$/.test(bucketName)) {
      throw new TosClientError(
        `invalid bucket name, the bucket name can be neither starting with '-' nor ending with '-'`
      );
    }

    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    writeHeaders(headers, 'x-tos-acl', input.ACL);
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-az-redundancy', input.AzRedundancy);
    writeHeaders(headers, 'x-tos-project-name', input.ProjectName);
    writeHeaders(headers, 'x-tos-grant-full-control', input.GrantFullControl);
    writeHeaders(headers, 'x-tos-grant-read', input.GrantRead);
    writeHeaders(headers, 'x-tos-grant-read-acp', input.GrantReadAcp);
    writeHeaders(headers, 'x-tos-grant-write', input.GrantWrite);
    writeHeaders(headers, 'x-tos-grant-write-acp', input.GrantWriteAcp);
    const res = await this.fetchBucket(input.Bucket, 'PUT', {}, headers)
    const output = {} as CreateBucketOutput;
    output.Location = res.headers['location'] ?? '';
    withRequestInfo(output, res);
    return output;
  }
  headBucket = async (input: HeadBucketInput): Promise<HeadBucketOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'HEAD', {}, {})
    const output = {
      Region: res.headers['x-tos-bucket-region'] ?? '',
      StorageClass: res.headers['x-tos-storage-class'] as StorageClassType,
      AzRedundancy: res.headers['x-tos-az-redundancy'] as AzRedundancyType,
      ProjectName: res.headers['x-tos-project-name'],
    } as HeadBucketOutput;
    withRequestInfo(output, res);
    return output;
  }
  deleteBucket = async (input: DeleteBucketInput): Promise<DeleteBucketOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'DELETE', {}, {})
    const output = {} as DeleteBucketOutput;
    withRequestInfo(output, res);
    return output;
  }
  getBucketLocation = async (input: GetBucketLocationInput): Promise<GetBucketLocationOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'GET', {
      location: '',
    }, {})
    const output = res.data as GetBucketLocationOutput;
    withRequestInfo(output, res);
    return output;
  }
  putBucketEncryption = async (input: PutBucketEncryptionInput): Promise<PutBucketEncryptionOutput> => {
    const body: Partial<GetBucketEncryptionOutput> = {
      Rule: input.Rule
    }
    const res = await this.fetchBucket(input.Bucket, 'PUT', {
      encryption: ''
    }, {
      'Content-MD5': hashMd5(
        JSON.stringify(body),
        'base64'
      ) as string,
    }, body
    );
    const output = {} as PutBucketEncryptionOutput;
    withRequestInfo(output, res);
    return output;
  }
  getBucketEncryption = async (input: GetBucketEncryptionInput): Promise<GetBucketEncryptionOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'GET', {
      encryption: ''
    }, {})
    const output = res.data as GetBucketEncryptionOutput;
    withRequestInfo(output, res);
    return output;
  }
  deleteBucketEncryption = async (input: DeleteBucketEncryptionInput): Promise<DeleteBucketEncryptionOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'DELETE', {
      encryption: '',
    }, {})
    const output = {} as DeleteBucketEncryptionOutput;
    withRequestInfo(output, res);
    return output;
  }
  putBucketMirrorBack = async (input: PutBucketMirrorBackInput): Promise<PutBucketMirrorBackOutput> => {
    const body: BucketMirrorBackRuleBody = {
      Rules: input.Rules
    }
    const res = await this.fetchBucket(
      input.Bucket,
      'PUT',
      { 'mirror': '' },
      {},
      body
    );
    const output = {} as PutBucketMirrorBackOutput;
    withRequestInfo(output, res);
    return output;
  }
  getBucketMirrorBack = async (input: GetBucketMirrorBackInput): Promise<GetBucketMirrorBackOutput> => {
    const res = await this.fetchBucket(
      input.Bucket,
      'GET',
      { 'mirror': '' },
      {}
    );
    const output = res.data as GetBucketMirrorBackOutput;
    withRequestInfo(output, res);
    return output;
  }
  deleteBucketMirrorBack = async (input: DeleteBucketMirrorBackInput): Promise<DeleteBucketMirrorBackOutput> => {
    const res = await this.fetchBucket(
      input.Bucket,
      'DELETE',
      { 'mirror': '' },
      {}
    );
    const output = {} as DeleteBucketMirrorBackOutput;
    withRequestInfo(output, res);
    return output;
  }
  putBucketVersioning = async (input: PutBucketVersioningInput): Promise<PutBucketVersioningOutput> => {
    const body: BucketVersioningBody = {
      Status: input.Status
    }
    const res = await this.fetchBucket(
      input.Bucket,
      'PUT',
      { 'versioning': '' },
      {},
      body
    );
    const out = {} as PutBucketVersioningOutput
    withRequestInfo(out, res);
    return out;
  }
  getBucketVersioning = async (input: GetBucketVersioningInput): Promise<GetBucketVersioningOutput> => {
    const res = await this.fetchBucket(
      input.Bucket,
      'GET',
      { 'versioning': '' },
      {}
    );
    const out = res.data as GetBucketVersioningOutput;
    if (!out.Status) {
      out.Status = VersioningStatusType.VersioningStatusNotSet
    }
    withRequestInfo(out, res);
    return out;
  }
  putObject = async (input: PutObjectInput) => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    writeHeaders(headers, 'content-length', input.ContentLength);
    writeHeaders(headers, 'x-tos-callback', input.Callback);
    writeHeaders(headers, 'x-tos-callback-var', input.CallbackVar);
    writeHeaders(headers, 'content-md5', input.ContentMD5);
    writeHeaders(headers, 'x-tos-content-sha256', input.ContentSHA256);
    writeHeaders(headers, 'cache-control', input.CacheControl)
    if (input.ContentDisposition) {
      writeHeaders(headers, 'content-disposition', encodeContentDisposition(input.ContentDisposition))
    }
    writeHeaders(headers, 'content-encoding', input.ContentEncoding);
    writeHeaders(headers, 'content-language', input.ContentLanguage);
    writeHeaders(headers, 'content-type', input.ContentType)
    writeHeaders(headers, 'expires', input.Expires?.toUTCString());
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers,'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    writeMeta(headers, input.Meta)
    const getContent = () => {
      if (input.Content instanceof ArrayBuffer && input.Content.byteLength === 0) {
        return;
      }
      return input.Content;
    }

    const newContent = getContent();
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key
    }, 'PUT', {}, headers, newContent, {
      isStreamReq: newContent instanceof rcp.UploadFromStream || newContent instanceof rcp.UploadFromFile,
    })
    const output = {
      HashCrc64ecma: res.headers['x-tos-hash-crc64ecma']
    } as PutObjectOutput;
    withRequestInfo(output, res);
    if (input.Callback) {
      output.CallbackResult = JSON.stringify(res.data);
    }
    return output;
  }
  putObjectFromFile = async (input: PutObjectFromFileInput): Promise<PutObjectFromFileOutput> => {
    const input2 = input as PutObjectInput;
    const uploadFromStream = new rcp.UploadFromStream(fs.createStreamSync(input.FilePath, 'r+'))
    input2.Content = uploadFromStream;
    return this.putObject(input2)
  }

  uploadFile = async (input: UploadFileInput): Promise<UploadFileOutput> => {
    const fileStat = await fs.stat(input.FilePath);
    const fileSize = fileStat.size;
    const checkpointRichInfo = await parseCheckpointRecord<CheckpointRecord>({
      EnableCheckpoint: input.EnableCheckpoint,
      CheckpointFile: input.CheckpointFile,
      Bucket: input.Bucket,
      Key: input.Key,
      FilePath: input.FilePath
    })

    if (checkpointRichInfo.record?.file_info) {
      // last modified
      if (checkpointRichInfo.record?.file_info.file_size !== fileSize) {
        checkpointRichInfo.record = undefined;
      }
      const lastModified = checkpointRichInfo.record?.file_info.last_modified;
      if (lastModified && lastModified !== fileStat.mtime) {
        checkpointRichInfo.record = undefined;
      }
    }

    const partSize = calculateSafePartSize(
      fileSize,
      input.PartSize || checkpointRichInfo.record?.part_size || DEFAULT_PART_SIZE,
      true
    );

    if (checkpointRichInfo.record) {
      const cpRecord = checkpointRichInfo.record;
      if (cpRecord.bucket !== input.Bucket || cpRecord.key !== input.Key || cpRecord.part_size !== partSize) {
        checkpointRichInfo.record = undefined;
      }
    }

    const initConsumedBytes = (checkpointRichInfo.record?.parts_info || [])
      .filter((it) => it.is_completed)
      .reduce((prev, it) => prev + it.part_size, 0);

    const allTasks = getAllTasks(fileSize, partSize);
    let tasks: Task[]
    const recordedTasks = checkpointRichInfo.record?.parts_info || [];
    const recordedTaskMap: Map<number, CheckpointRecordPart> = new Map();
    recordedTasks.forEach((it) => recordedTaskMap.set(it.part_number, it));
    let uploadId = '';
    const triggerUploadEvent = (type: UploadEventType, uploadPartInfo?: UploadPartInfo, err?: Error) => {
      if (!input.UploadEventListener) {
        return;
      }

      const event: UploadEvent = {
        Type: type,
        Err: err,
        Bucket: input.Bucket,
        Key: input.Key,
        FilePath: input.FilePath,
        UploadID: uploadId,
        CheckpointFile: checkpointRichInfo.filePath,
        UploadPartInfo: uploadPartInfo,
      };

      input.UploadEventListener.EventChange(event);
    }

    let consumedBytes = initConsumedBytes;
    const triggerDataTransfer = (
      type: DataTransferType,
      rwOnceBytes: number = 0
    ) => {
      if (!input.DataTransferListener) {
        return;
      }
      consumedBytes += rwOnceBytes;

      input.DataTransferListener.DataTransferStatusChange({
        Type:type,
        RWOnceBytes: rwOnceBytes,
        ConsumedBytes: consumedBytes,
        TotalBytes: fileSize,
      });
    };

    const rmCheckpointFile = async () => {
      try {
        await fs.unlink(checkpointRichInfo.filePath)
      } catch (e) {
        console.log('remove checkpoint file failure, you can remove it by hand.\n',
          `checkpoint file path: ${checkpointRichInfo.filePath}\n`,
          e.message
        );
      }
    }

    const cancel = async () => {
      if (input.CancelHook?.isCanceled) {
        if (input.CancelHook.isAbort) {
          await rmCheckpointFile();
        }
        throw new CancelError('cancel uploadFile')
      }
    }

    if (checkpointRichInfo.record) {
      uploadId = checkpointRichInfo.record.upload_id;
      const uploadedPartSet: Set<number> = new Set(
        (checkpointRichInfo.record.parts_info || [])
          .filter((it) => it.is_completed)
          .map((it) => it.part_number)
      );
      tasks = allTasks.filter((it) => !uploadedPartSet.has(it.partNumber));
    } else  {
      tasks = allTasks;
      try {
        const createMultipartUploadRes = await this.createMultipartUpload(input);
        await cancel();
        uploadId = createMultipartUploadRes.UploadId;
        triggerUploadEvent(UploadEventType.CreateMultipartUploadSucceed);
      } catch (e) {
        triggerUploadEvent(UploadEventType.CreateMultipartUploadFailed, undefined, e);
        throw e as Error
      }
    }

    const getCheckpointContent = () => {
      const checkpointContent: CheckpointRecord = {
        bucket: input.Bucket,
        key: input.Key,
        part_size: partSize,
        upload_id: uploadId,
        parts_info: recordedTasks,
        file_info: {
          last_modified: fileStat.mtime,
          file_size: fileStat.size,
        }
      };
      return checkpointContent;
    };

    const writeCheckpointFile = async () => {
      try {
        const content = JSON.stringify(getCheckpointContent(), null, 2);
        if (checkpointRichInfo.filePath) {
          const dirName = getDirName(checkpointRichInfo.filePath);
          try {
            await fs.mkdir(dirName, true)
          } catch (e) {}
          const file = await fs.open(checkpointRichInfo.filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
          await fs.write(file.fd, content);
          await fs.close(file);
        }
      } catch (e) {
        console.log('write checkpoint file failure', e.message)
      }
    }

    const updateAfterUploadPart = async (task: Task, uploadPartRes: UploadPartOutput | null, err: Error | null) => {
      let existRecordTask = recordedTaskMap.get(task.partNumber);
      if (!existRecordTask) {
        existRecordTask = {
          part_number: task.partNumber,
          offset: task.offset,
          part_size: task.partSize,
          is_completed: false,
          etag: '',
          hash_crc64ecma: '',
        };
        recordedTasks.push(existRecordTask);
        recordedTaskMap.set(existRecordTask.part_number, existRecordTask);
      }

      if (!err) {
        existRecordTask.is_completed = true;
        existRecordTask.etag = uploadPartRes?.ETag || ''
        existRecordTask.hash_crc64ecma = uploadPartRes?.HashCrc64ecma || '';
      }

      await writeCheckpointFile();
      const uploadPartInfo: UploadPartInfo = {
        PartNumber: existRecordTask.part_number,
        PartSize: existRecordTask.part_size,
        Offset: existRecordTask.offset,
        ETag: existRecordTask.etag || '',
        HashCrc64ecma: existRecordTask.hash_crc64ecma || ''
      };

      if (!err) {
        triggerUploadEvent(UploadEventType.UploadPartSucceed, uploadPartInfo)
      } else {
        triggerUploadEvent(UploadEventType.UploadPartFailed, uploadPartInfo, err);
        if (err instanceof TosServerError &&  [403, 404, 405].includes(err.StatusCode)) {
          triggerUploadEvent(UploadEventType.UploadPartAborted, uploadPartInfo, err as Error);
        }
      }
    }

    const handleTasks = async () => {
      let firstErr: Error | null = null;
      let index = 0;

      await Promise.all(new Array(input.TaskNum || 1).fill(0).map(async () => {
        while (true) {
          const currentIndex = index++;
          if (currentIndex >= tasks.length) {
            return;
          }
          const curTask = tasks[currentIndex];
          let consumedBytesThisTask = 0;
          try {
            const arrayBuffer = new ArrayBuffer(curTask.partSize);
            const file = await fs.open(input.FilePath);
            await fs.read(file.fd, arrayBuffer, {
              offset: curTask.offset,
              length: curTask.partSize
            });
            await fs.close(file);
            const uploadPartRes = await this.uploadPart({
              Bucket: input.Bucket,
              Key: input.Key,
              UploadID: uploadId,
              PartNumber: curTask.partNumber,
              Content: arrayBuffer,
              SSECAlgorithm: input.SSECAlgorithm,
              SSECKey: input.SSECKey,
              SSECKeyMD5: input.SSECKeyMD5,
              DataTransferListener: {
                DataTransferStatusChange(status){
                  if (status.Type !== DataTransferType.RW) {
                    return;
                  }
                  consumedBytesThisTask += status.RWOnceBytes;
                  triggerDataTransfer(status.Type, status.RWOnceBytes);
                }
              }
            })
            await cancel();
            await updateAfterUploadPart(curTask, uploadPartRes, null);
          } catch (e) {
            if (!firstErr) {
              firstErr = e;
            }
            await cancel();
            consumedBytes -= consumedBytesThisTask;
            consumedBytesThisTask = 0;
            await updateAfterUploadPart(curTask, null, e);
          }
        }
      }))

      if (firstErr) {
        throw firstErr as Error
      }

      const parts = (getCheckpointContent().parts_info || []).map((it) => {
        return new UploadedPart(it.part_number, it.etag);
      });
      try {
        const res = await this.completeMultipartUpload({
          Bucket: input.Bucket,
          Key: input.Key,
          UploadID: uploadId,
          Parts: parts
        })
        triggerUploadEvent(UploadEventType.CompleteMultipartUploadSucceed);
        return res;
      } catch (e) {
        triggerUploadEvent(UploadEventType.CompleteMultipartUploadFailed, undefined, e);
        throw e as Error;
      }
    }

    try {
      triggerDataTransfer(DataTransferType.Started);
      const res = await handleTasks();
      triggerDataTransfer(DataTransferType.Succeed);
      await rmCheckpointFile();
      return res;
    } catch (e) {
      triggerDataTransfer(DataTransferType.Failed);
      throw e as Error
    }
  }

  private getCopySourceHeader = (srcBucket: string, srcKey: string) => {
    return `/${srcBucket}/${encodeURIComponent(srcKey)}`;
  }
  copyObject = async (input: CopyObjectInput): Promise<CopyObjectOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    writeHeaders(headers, 'cache-control', input.CacheControl)
    if (input.ContentDisposition) {
      writeHeaders(headers, 'content-disposition', encodeContentDisposition(input.ContentDisposition))
    }
    writeHeaders(headers, 'content-encoding', input.ContentEncoding);
    writeHeaders(headers, 'content-language', input.ContentLanguage);
    writeHeaders(headers, 'content-type', input.ContentType)
    writeHeaders(headers, 'x-tos-copy-source-if-match', input.CopySourceIfMatch);
    writeHeaders(headers, 'x-tos-copy-source-if-modified-since', input.CopySourceIfModifiedSince?.toUTCString());
    writeHeaders(headers, 'x-tos-copy-source-if-none-match', input.CopySourceIfNoneMatch);
    writeHeaders(headers, 'x-tos-copy-source-if-unmodified-since', input.CopySourceIfUnmodifiedSince?.toUTCString());
    writeHeaders(headers, 'x-tos-copy-source-server-side-encryption-customer-algorithm', input.CopySourceSSECAlgorithm);
    writeHeaders(headers, 'x-tos-copy-source-server-side-encryption-customer-key', input.CopySourceSSECKey);
    writeHeaders(headers, 'x-tos-copy-source-server-side-encryption-customer-key-MD5', input.CopySourceSSECKeyMD5);

    writeHeaders(headers, 'expires', input.Expires?.toUTCString());
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    writeHeaders(headers, 'x-tos-metadata-directive', input.MetadataDirective);
    writeMeta(headers, input.Meta)

    let copySource = this.getCopySourceHeader(input.SrcBucket, input.SrcKey);
    if (input.SrcVersionID) {
      copySource += `?versionId=${input.SrcVersionID}`;
    }
    headers['x-tos-copy-source'] = copySource;
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key,
    }, 'PUT', {}, headers)
    return withCopyObjectOutput(res)
  }
  headObject = async (input: HeadObjectInput): Promise<HeadObjectOutput> => {
    const query: Query = {};
    if (input.VersionID) {
      query.versionId = input.VersionID;
    }
    const headers: Headers = {};
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
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);

    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key,
    }, 'HEAD', query, headers)
    return withHeadObjectOutput(res);
  }
  getObject = async (input: GetObjectInput) => {
    const query: Query = {};
    writeQuery(query, 'versionId', input.VersionId)
    const headers = makeGetObjectHeaders(input);

    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key
    }, 'GET', query, headers, undefined, {
      isStreamResp: true,
    })
    return withGetObjectOutput(res);
  }

  // _getObject = async (input: GetObjectInput) => {
  //   const query: Query = {};
  //   writeQuery(query, 'versionId', input.VersionId)
  //   const headers = makeGetObjectHeaders(input);
  //   const buf = buffer.alloc(0);
  //
  //   const res = await this._fetchObject({
  //     bucket: input.Bucket,
  //     key: input.Key
  //   }, 'GET', query, headers, undefined, {
  //     onDataReceive: (data) => {
  //       console.log('_getObject ===> ', data.byteLength)
  //
  //     }
  //   })
  //   const output = withGetObjectOutput(res);
  //   const output2 = output as Any as InnerGetObjectOutput;
  //   return output2
  // }
  // getObjectToFile = async (input: GetObjectToFileInput): Promise<GetObjectToFileOutput> => {
  //   const query: Query = {};
  //   writeQuery(query, 'versionId', input.VersionId)
  //   const headers = makeGetObjectHeaders(input);
  //   const res = await this._fetchObject({
  //     bucket: input.Bucket,
  //     key: input.Key
  //   }, 'GET', query, headers, undefined, {
  //     filePath: input.FilePath
  //   })
  //   return withGetObjectOutput(res);
  // }
  downloadFile = async (input: DownloadFileInput) => {
    const headObjectRes = await this.headObject(input);
    const objectSize = headObjectRes.ContentLength;
    const checkpointRichInfo = await parseCheckpointRecord<DownloadFileCheckpointRecord>({
      EnableCheckpoint: input.EnableCheckpoint,
      CheckpointFile: input.CheckpointFile,
      Bucket: input.Bucket,
      Key: input.Key,
      FilePath: input.FilePath
    })

    if (checkpointRichInfo.record?.object_info) {
      const object_info = checkpointRichInfo.record?.object_info
      if (objectSize !== object_info.object_size) {
        checkpointRichInfo.record = undefined;
      }

      const last_modified = object_info.last_modified;
      if (last_modified && last_modified !== headObjectRes.Headers['last-modified']) {
        checkpointRichInfo.record = undefined;
      }
    }

    const partSize = input.PartSize || checkpointRichInfo.record?.part_size || DEFAULT_PART_SIZE;
    if (checkpointRichInfo.record && checkpointRichInfo.record.part_size !== partSize) {
      checkpointRichInfo.record = undefined;
    }

    let filePath = input.FilePath;
    if (await isDirectory(input.FilePath)){
      const split = input.FilePath.endsWith('/') ? '' : '/';
      filePath = input.FilePath + split + input.Key
    }
    const dirName = getDirName(filePath);
    try {
      await fs.mkdir(dirName, true);
    } catch (e) {}
    const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)

    let tasks: Task[] = [];
    const allTasks: Task[] = getAllTasks(objectSize, partSize);
    const initConsumedBytes = (checkpointRichInfo.record?.parts_info || [])
      .filter((it) => it.is_completed)
      .reduce((prev, it) => prev + (it.range_end - it.range_start + 1), 0);
    const recordedTasks = checkpointRichInfo.record?.parts_info || [];
    const recordedTaskMap: Map<number, DownloadFileCheckpointRecordPartInfo> =
      new Map();
    recordedTasks.forEach((it) => recordedTaskMap.set(it.part_number, it));

    if (checkpointRichInfo.record) {
      const uploadedPartSet: Set<number> = new Set(
        (checkpointRichInfo.record.parts_info || [])
          .filter((it) => it.is_completed)
          .map((it) => it.part_number)
      );
      tasks = allTasks.filter((it) => !uploadedPartSet.has(it.partNumber));
    } else {
      tasks = allTasks;
    }

    const getCheckpointContent = () => {
      const checkpointContent: DownloadFileCheckpointRecord = {
        bucket: input.Bucket,
        key: input.Key,
        version_id: input.VersionID,
        part_size: partSize,
        parts_info: recordedTasks,
        file_info: {
          file_path: filePath,
        },
        object_info: {
          last_modified: headObjectRes.Headers['last-modified'] || '',
          etag: headObjectRes.ETag,
          hash_crc64ecma: headObjectRes.HashCrc64ecma || '',
          object_size: objectSize,
        },
      };
      return checkpointContent;
    };

    let consumedBytes = initConsumedBytes;
    const triggerDataTransfer = (
      type: DataTransferType,
      rwOnceBytes: number = 0
    ) => {
      if (!input.DataTransferListener) {
        return;
      }
      consumedBytes += rwOnceBytes;

      input.DataTransferListener.DataTransferStatusChange({
        Type: type,
        RWOnceBytes: rwOnceBytes,
        ConsumedBytes: consumedBytes,
        TotalBytes: objectSize,
      });
    };

    const writeCheckpointFile = async () => {
      try {
        const content = JSON.stringify(getCheckpointContent(), null, 2);
        if (checkpointRichInfo.filePath) {
          const dirName = getDirName(checkpointRichInfo.filePath);
          try {
            await fs.mkdir(dirName, true)
          } catch (e) {}
          const file = await fs.open(checkpointRichInfo.filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
          await fs.write(file.fd, content);
          await fs.close(file);
        }
      } catch (e) {
        console.log('write checkpoint file failure', e.message)
      }
    }

    const rmCheckpointFile = async () => {
      try {
        await fs.unlink(checkpointRichInfo.filePath)
      } catch (e) {
        console.log('remove checkpoint file failure, you can remove it by hand.\n',
          `checkpoint file path: ${checkpointRichInfo.filePath}\n`,
          e.message
        );
      }
    }

    const cancel = async () => {
      if (input.CancelHook?.isCanceled) {
        if (input.CancelHook.isAbort) {
          await rmCheckpointFile();
        }
        throw new CancelError('cancel downloadFile')
      }
    }

    const updateAfterDownloadPart = async (task: Task, getObjectRes?: GetObjectOutput, err?: Error) => {
      let existRecordTask = recordedTaskMap.get(task.partNumber);
      const rangeStart = task.offset;
      const rangeEnd = Math.min(task.offset + partSize - 1, objectSize - 1);
      if (!existRecordTask) {
        existRecordTask = {
          part_number: task.partNumber,
          range_start: rangeStart,
          range_end: rangeEnd,
          hash_crc64ecma: '',
          is_completed: false,
        };
        recordedTasks.push(existRecordTask);
        recordedTaskMap.set(existRecordTask.part_number, existRecordTask);
      }

      if (!err) {
        existRecordTask.is_completed = true;
      }
      await writeCheckpointFile();
    }

    const handleTasks = async () => {
      let firstErr: Error | null = null;
      let index = 0;
      await Promise.all(new Array(input.TaskNum || 1).fill(0).map(async () => {
        while (true) {
          const currentIndex = index++;
          if (currentIndex >= tasks.length) {
            return;
          }
          const curTask = tasks[currentIndex];
          try {
            const query: Query = {};
            writeQuery(query, 'versionId', input.VersionID)
            const headers = makeGetObjectHeaders({
              Bucket: input.Bucket,
              Key: input.Key,
              VersionId: input.VersionID,
              IfMatch: input.IfMatch,
              IfModifiedSince: input.IfModifiedSince,
              IfNoneMatch: input.IfNoneMatch,
              IfUnmodifiedSince: input.IfUnmodifiedSince,
              SSECAlgorithm: input.SSECAlgorithm,
              SSECKey: input.SSECKey,
              SSECKeyMD5: input.SSECKeyMD5,
              Range: `bytes=${curTask.offset}-${Math.min(
                curTask.offset + curTask.partSize - 1,
                objectSize - 1
              )}`
            });
            let offset = curTask.offset;
            const res = await this._fetchObject({
              bucket: input.Bucket,
              key: input.Key
            }, 'GET', query, headers, undefined, {
              onDataReceive: async  (data) => {
                triggerDataTransfer(DataTransferType.RW, data.byteLength)
                await cancel();
                await fs.write(file.fd, data, {
                  offset,
                })
                offset += data.byteLength
              }
            })
            await cancel();
            await updateAfterDownloadPart(curTask, withGetObjectOutput(res))
          } catch (e) {
            if (!firstErr) {
              firstErr = e as Error
            }
            await cancel();
            await updateAfterDownloadPart(curTask, undefined, e);
          }
        }
      }))

      if (firstErr) {
        throw firstErr as Error
      }
    }

    triggerDataTransfer(DataTransferType.Started);
    try {
      if (objectSize > 0) {
        await handleTasks();
      }
      triggerDataTransfer(DataTransferType.Succeed);
      await rmCheckpointFile();
      return headObjectRes;
    } catch (e) {
      triggerDataTransfer(DataTransferType.Failed);
      throw e as Error
    } finally {
      await fs.close(file.fd);
    }
  }

  deleteObject = async (input: DeleteObjectInput): Promise<DeleteObjectOutput> => {
    const query: Query = {}
    if (input.VersionID) {
      query.versionId = input.VersionID;
    }
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key,
    }, 'DELETE', query, {})
    const output = {
      DeleteMarker: !!res.headers['x-tos-delete-marker'],
      VersionID: res.headers['x-tos-version-id']
    } as DeleteObjectOutput
    withRequestInfo(output, res);
    return output;
  }
  setObjectMeta = async (input: SetObjectMetaInput): Promise<SetObjectMetaOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    const query: Query = { metadata: '' }
    if (input.VersionId) {
      query.versionId = input.VersionId;
    }
    writeHeaders(headers, 'cache-control', input.CacheControl);
    if (input.ContentDisposition){
      writeHeaders(headers, 'content-disposition', encodeContentDisposition(input.ContentDisposition))
    }
    writeHeaders(headers, 'content-encoding', input.ContentEncoding);
    writeHeaders(headers, 'content-language', input.ContentLanguage);
    writeHeaders(headers, 'content-type', input.ContentType)
    writeHeaders(headers, 'expires', input.Expires?.toUTCString());
    writeMeta(headers, input.Meta);
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key,
    }, 'POST', query, headers)
    const output = {} as SetObjectMetaOutput;
    withRequestInfo(output, res);
    return output;
  }
  appendObject = async (input: AppendObjectInput): Promise<AppendObjectOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {}
    writeHeaders(headers, 'content-length', input.ContentLength);
    writeHeaders(headers, 'cache-control', input.CacheControl);
    if (input.ContentDisposition){
      writeHeaders(headers, 'content-disposition', input.ContentDisposition)
    }
    writeHeaders(headers, 'content-encoding', input.ContentEncoding);
    writeHeaders(headers, 'content-language', input.ContentLanguage);
    writeHeaders(headers, 'content-type', input.ContentType)
    writeHeaders(headers, 'expires', input.Expires?.toUTCString());
    // writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeMeta(headers, input.Meta)
    const query: Query = {};
    query.append = '';
    writeQuery(query, 'offset', input.Offset)
    const getContent = () => {
      if (input.Content instanceof ArrayBuffer && input.Content.byteLength === 0) {
        return;
      }
      return input.Content;
    }

    const newContent = getContent();

    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key
    }, 'POST', query, headers, newContent, {
      isStreamReq: input.Content instanceof rcp.UploadFromStream
    })
    const output = {} as AppendObjectOutput;
    withRequestInfo(output, res);
    output.NextAppendOffset = Number(res.headers['x-tos-next-append-offset']);
    output.HashCrc64ecma = res.headers['x-tos-hash-crc64ecma'];
    return output;
  }
  private listObjectsType2Once = async (input: ListObjectsType2Input) => {
    const query: Query = {
      'list-type': 2
    };
    if (input.Prefix) {
      query.prefix = input.Prefix;
    }
    if (input.Delimiter) {
      query.delimiter = input.Delimiter;
    }
    if (input.StartAfter) {
      query['start-after'] = input.StartAfter;
    }
    if (input.ContinuationToken) {
      query['continuation-token'] = input.ContinuationToken;
    }
    if (input.MaxKeys !== undefined) {
      query['max-keys'] = input.MaxKeys;
    }
    if (input.EncodingType) {
      query['encoding-type'] = input.EncodingType;
    }

    const res = await this.fetchBucket(input.Bucket, 'GET', query, {})
    const output = res.data as ListObjectsType2Output;
    if (!output.Contents) {
      output.Contents = [];
    }
    if (!output.CommonPrefixes) {
      output.CommonPrefixes = [];
    }
    if (!output.KeyCount) {
      output.KeyCount = 0;
    }

    withRequestInfo(output, res);
    return output;
  }
  listObjectsType2 = async (input: ListObjectsType2Input): Promise<ListObjectsType2Output> => {
    if (isNil(input.MaxKeys)) {
      input.MaxKeys = this.DefaultListMaxKeys;
    }
    if (input.ListOnlyOnce) {
      return this.listObjectsType2Once(input)
    }
    let output: ListObjectsType2Output | undefined;
    const params: ListObjectsType2Input = {
      Bucket: input.Bucket,
      Prefix: input.Prefix,
      Delimiter: input.Delimiter,
      StartAfter: input.StartAfter,
      ContinuationToken: input.ContinuationToken,
      MaxKeys: input.MaxKeys,
      EncodingType: input.EncodingType
    }
    while (true) {
      const res = await this.listObjectsType2Once(params)
      if (!output) {
        output = res;
      } else {
        output.KeyCount += res.KeyCount;
        output.IsTruncated = res.IsTruncated;
        output.NextContinuationToken = res.NextContinuationToken;
        output.Contents = output.Contents.concat(res.Contents);
        output.CommonPrefixes = output.CommonPrefixes.concat(
          res.CommonPrefixes
        );
      }

      if (!res.IsTruncated || output.KeyCount >= Number(input.MaxKeys)) {
        break;
      }

      params.ContinuationToken = res.NextContinuationToken;
      params.MaxKeys = Number(params.MaxKeys) - res.KeyCount;
    }
    return output as ListObjectsType2Output;
  }
  listObjectVersions = async (input: ListObjectVersionsInput): Promise<ListObjectVersionsOutput> => {
    const query: Query = {
      versions: ''
    };
    writeQuery(query, 'prefix', input.Prefix);
    writeQuery(query, 'delimiter', input.Delimiter);
    writeQuery(query, 'key-marker', input.KeyMarker);
    writeQuery(query, 'version-id-marker', input.VersionIDMarker);
    writeQuery(query, 'max-keys', input.MaxKeys ?? this.DefaultListMaxKeys);
    writeQuery(query, 'encoding-type', input.EncodingType);
    const res = await this.fetchBucket(input.Bucket, 'GET', query, {})
    const output = res.data as ListObjectVersionsOutput;
    if (!output.CommonPrefixes) {
      output.CommonPrefixes = [];
    }
    if (!output.Versions) {
      output.Versions = []
    }
    if (!output.DeleteMarkers) {
      output.DeleteMarkers = [];
    }
    withRequestInfo(output, res);
    return output;
  }
  deleteMultiObjects = async (input: DeleteMultiObjectsInput) => {
    const query: Query = {};
    const body: DeleteMultiObjectsBody = {
      Objects: input.Objects,
      Quiet: input.Quiet
    }
    query.delete = 'delete'
    const res = await this.fetchBucket(
      input.Bucket,
      'POST',
      query,
      {},
      body
    );
    const output = res.data as DeleteMultiObjectsOutput;
    withRequestInfo(output, res);
    return output;
  }
  fetchObject = async (input: FetchObjectInput): Promise<FetchObjectOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    writeMeta(headers, input.Meta);

    const res = await this._fetchObject(
      {
        bucket: input.Bucket,
        key: input.Key,
      },
      'POST',
      {
        fetch: '',
      },
      headers,
      {
        URL: input.URL,
        IgnoreSameKey: input.IgnoreSameKey,
        ContentMD5: input.ContentMD5,
      },
      {
        needMd5: true,
      }
    );
    const out = res.data as FetchObjectOutput;
    withRequestInfo(out, res);
    if (res.headers['x-tos-version-id']) {
      out.VersionID = res.headers['x-tos-version-id']
    }
    if (res.headers['x-tos-server-side-encryption-customer-algorithm']) {
      out.SSECAlgorithm = res.headers['x-tos-server-side-encryption-customer-algorithm']
    }
    if (res.headers['x-tos-server-side-encryption-customer-key-md5']) {
      out.SSECKeyMD5 = res.headers['x-tos-server-side-encryption-customer-key-md5']
    }
    return out;
  }
  putFetchTask = async (input: PutFetchTaskInput): Promise<PutFetchTaskOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {}
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    writeMeta(headers, input.Meta);
    const body: PutFetchTaskBody = {
      URL: input.URL,
      Object: input.Key,
      IgnoreSameKey: input.IgnoreSameKey,
      ContentMD5: input.ContentMD5
    }
    const res = await this.fetchBucket(input.Bucket, 'POST', {
      fetchTask: ''
    }, headers, body)
    const output = res.data as PutFetchTaskOutput;
    withRequestInfo(output, res);
    return output;
  }
  getFetchTask = async (input: GetFetchTaskInput): Promise<GetFetchTaskOutput> => {
    const headers: Headers = {};
    const res = await this.fetchBucket(input.Bucket, 'GET', {
      fetchTask: '',
      taskId: input.TaskID,
    }, headers);
    const output = res.data as GetFetchTaskOutput;
    withRequestInfo(output, res);
    output.Task.Meta = userMeta2Meta(res.data as RawGetFetchTaskBody)
    return output;
  }

  private getSignatureQuery(
    input: GetSignatureQueryInput
  ): Record<string, string | undefined> {
    const signv4 = new ISigV4Credentials(
      this.opts.securityToken,
      this.opts.accessKeySecret,
      this.opts.accessKeyId
    );

    const sig = new SignersV4(
      {
        algorithm: 'TOS4-HMAC-SHA256',
        region: this.opts.endpoint,
        serviceName: 'tos',
        // SignV4 uses this.options.bucket, so set it here
        bucket: input.bucket,
        securityToken: this.opts.securityToken,
      },
      signv4
    );
    return sig.getSignatureQuery(
      {
        method: input.method,
        path: input.path,
        endpoints: input.subdomain ? input.endpoint : undefined,
        host: input.endpoint,
        query: input.query,
      },
      input.expires
    );
  }

  preSignedURL = async (input: PreSignedURLInput): Promise<PreSignedURLOutput> => {
    //const endpoint = input.AlternativeEndpoint || this.opts.endpoint;
    let endpoint = this.opts.endpoint;
    let scheme = this.scheme;
    if (input.AlternativeEndpoint) {
      const schemeHostRes = schemeHost(input.AlternativeEndpoint);
      scheme = schemeHostRes.scheme;
      endpoint = schemeHostRes.host;
    }
    const subdomain =
      input.AlternativeEndpoint || input.IsCustomDomain
        ? false
        : true;
    const bucket = input.Bucket;
    if (subdomain && !bucket) {
      throw new TosClientError('Must provide bucket param');
    }

    const arr = (() => {
      const encodedKey = encodeURIComponent(input.Key);
      const objectKeyPath = input.Key
        .split('/')
        .map((it) => encodeURIComponent(it))
        .join('/');

      if (subdomain) {
        return [`${bucket}.${endpoint}`, `/${objectKeyPath}`, `/${encodedKey}`];
      }
      return [endpoint, `/${objectKeyPath}`, `/${encodedKey}`];
    })();

    const newHost = arr[0];
    const newPath = arr[1];
    const signingPath = arr[2];
    const nextQuery: Record<string, string> = input.Query || {};
    const query = this.getSignatureQuery({
      bucket: bucket || '',
      method: input.HttpMethod || 'GET',
      path: signingPath as string,
      endpoint: endpoint as string,
      subdomain,
      expires: input.Expires || 1800,
      query: nextQuery,
    });
    const baseURL = `${scheme}://${newHost}`;
    const queryStr = Object.keys(query)
      .map((key) => {
        return `${encodeURIComponent(key)}=${encodeURIComponent(query[key] as string)}`;
      })
      .join('&');
    const output: PreSignedURLOutput = {
      SignedUrl: `${baseURL}${newPath}?${queryStr}`
    }
    return output;
  }
  preSignedPolicyURL = async (input: PreSignedPolicyURLInput): Promise<PreSignedPolicyURLOutput> => {
    const bucket = input.Bucket || '';
    const defaultExpires = 3600;
    const conditions: string[][] =
      input.Conditions.map((it) => [it.Operator || 'eq', '$key', it.Value]);
    conditions.push(['eq', '$bucket', bucket]);
    let endpoint = input.IsCustomDomain
          ? this.opts.endpoint
          : `${bucket}.${this.opts.endpoint}`
    let scheme = this.scheme;
    if (input.AlternativeEndpoint){
      const schemeHostRes = schemeHost(input.AlternativeEndpoint);
      scheme = schemeHostRes.scheme;
      endpoint = schemeHostRes.host;
    }
    const expires = input.Expires || defaultExpires;
    const baseURL = `${scheme}://${endpoint}`;
    const signv4 = new ISigV4Credentials(
      this.opts.securityToken,
      this.opts.accessKeySecret,
      this.opts.accessKeyId
    );
    const sig = new SignersV4(
      {
        algorithm: 'TOS4-HMAC-SHA256',
        region: this.opts.endpoint,
        serviceName: 'tos',
        // SignV4 uses this.options.bucket, so set it here
        bucket,
        securityToken: this.opts.securityToken,
      },
      signv4
    );
    const query = sig.getSignaturePolicyQuery({
      policy: {
        conditions,
      },
    }, expires)
    const queryStr = obj2QueryStr(query);
    const getSignedURLForList: GetSignedURLForList = (
      additionalQuery
    ) => {
      const str2 = obj2QueryStr(additionalQuery);
      const q = [queryStr, str2].filter(Boolean).join('&');
      return `${baseURL}?${q}`;
    };
    const getSignedURLForGetOrHead: GetSignedURLForGetOrHead =
      (key, additionalQuery) => {
        const str2 = obj2QueryStr(additionalQuery);
        const q = [queryStr, str2].filter(Boolean).join('&');
        // keep   '/'
        const keyPath = key
          .split('/')
          .map((it) => encodeURIComponent(it))
          .join('/');
        return `${baseURL}/${keyPath}?${q}`;
      };

    const output: PreSignedPolicyURLOutput = {
      GetSignedURLForList: getSignedURLForList,
      GetSignedURLForGetOrHead: getSignedURLForGetOrHead,
      SignedQuery: queryStr,
    }
    return output;
  };

  preSignedPostSignature = async (input: PreSignedPostSignatureInput): Promise<PreSignedPostSignatureOutput> => {
    const expires = input.Expires ?? 3600;
    const accessKeySecret = this.opts.accessKeySecret;
    const date = new Date();
    const expirationDateStr = getDateTimeStr({
      date: new Date(date.valueOf() + expires * 1000),
      type: 'ISO',
    })
    const dateStr = getDateTimeStr();
    const date8Str = dateStr.substring(0, 8);
    const service = 'tos';
    const requestStr = 'request';
    const kDate = hmacSha256ToUint8Array(accessKeySecret, date8Str);
    const kRegion = hmacSha256ToUint8Array(kDate, this.opts.region);
    const kService = hmacSha256ToUint8Array(kRegion, service);
    const signingKey = hmacSha256ToUint8Array(kService, requestStr);
    const credential = [
      this.opts.accessKeyId,
      date8Str,
      this.opts.region,
      service,
      requestStr,
    ].join('/');
    interface AddedInForm extends Record<string, string | undefined>{
      key: string;
      'x-tos-algorithm': 'TOS4-HMAC-SHA256',
      'x-tos-date': string,
      'x-tos-credential': string,
      'x-tos-security-token'?: string
    }
    const addedInForm: AddedInForm  = {
      key: input.Key,
      'x-tos-algorithm': 'TOS4-HMAC-SHA256',
      'x-tos-date': dateStr,
      'x-tos-credential': credential,
    };
    if (this.opts.securityToken) {
      addedInForm['x-tos-security-token'] = this.opts.securityToken;
    }
    // Object.keys(addedInForm).forEach((key: string) => {
    //   conditions.push({ [key]: `${value}` });
    // });
    interface Condition extends Record<string, string | undefined> {
      bucket?: string;
      key?: string;
      "x-tos-credential"?: string
      "x-tos-algorithm"?: string;
      "x-tos-date"?: string;
      'x-tos-security-token'?: string
    };
    interface Policy {
      expiration: string,
      conditions: Array<Condition| string[]>,
    }
    const conditions: Array<Condition| string[]> = [
      {
        bucket: input.Bucket
      },
      {
        key: input.Key
      },
      {
        'x-tos-algorithm': 'TOS4-HMAC-SHA256',
      },
      {
        'x-tos-date': dateStr,
      },
      {
        'x-tos-credential': credential,
      },
    ];
    if (this.opts.securityToken) {
      const c: Condition = {
        'x-tos-security-token': this.opts.securityToken
      }
      conditions.push(c)
    }
    if (input.Conditions) {
      for (const c of input.Conditions){
        if (c.Operator) {
          conditions.push([c.Operator, "$" +  c.Key, c.Value])
        } else  {
          const obj: Record<string, string> = {};
          obj[c.Key] = c.Value;
          conditions.push(obj);
        }
      }
    }
    const policy: Policy = {
      expiration: expirationDateStr,
      conditions,
    }
    const policyStr = JSON.stringify(policy);
    const policyBase64 = stringify(parse(policyStr, 'utf-8'), 'base64');
    const signature = hmacSha256ToStr(signingKey, policyBase64, 'hex');
    const output: PreSignedPostSignatureOutput = {
      OriginPolicy: policyStr,
      Policy: policyBase64,
      Algorithm: 'TOS4-HMAC-SHA256',
      Credential: credential,
      Date: dateStr,
      Signature: signature
    }
    return output;
  }

  // parts
  createMultipartUpload = async (input: CreateMultipartUploadInput): Promise<CreateMultipartUploadOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    writeHeaders(headers, 'encoding-type', input.EncodingType);
    writeHeaders(headers, 'cache-control', input.CacheControl)
    if (input.ContentDisposition){
      writeHeaders(headers, 'content-disposition', encodeContentDisposition(input.ContentDisposition))
    }
    writeHeaders(headers, 'content-encoding', input.ContentEncoding);
    writeHeaders(headers, 'content-language', input.ContentLanguage);
    writeHeaders(headers, 'content-type', input.ContentType)
    writeHeaders(headers, 'expires', input.Expires?.toUTCString());
    writeHeaders(headers, 'x-tos-storage-class', input.StorageClass);
    writeHeaders(headers, 'x-tos-acl', input.ACL)
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    writeMeta(headers, input.Meta)
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key,
    }, 'POST', {
      uploads: ''
    }, headers)
    const output = res.data as CreateMultipartUploadOutput;
    withRequestInfo(output, res);
    withSSEC(output as OutputWithSSEC, res.headers);
    return output;
  }
  listMultipartUploads = async (input: ListMultipartUploadsInput): Promise<ListMultipartUploadsOutput> => {
    const res = await this.fetchBucket(input.Bucket, 'GET', {
      uploads: '',
      prefix: input.Prefix,
      delimiter: input.Delimiter,
      "key-marker": input.KeyMarker,
      "upload-id-marker": input.UploadIdMarker,
      "max-uploads": input.MaxUploads,
      "encoding-type": input.EncodingType
    }, {})
    const output = res.data as ListMultipartUploadsOutput;
    if (!output.CommonPrefixes) {
      output.CommonPrefixes = []
    }
    ;
    if (!output.Uploads) {
      output.Uploads = []
    }
    if (output.IsTruncated === undefined) {
      output.IsTruncated = false;
    }
    return output;
  }
  uploadPart = async (input: UploadPartInput): Promise<UploadPartOutput> => {
    const headers: Headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    if (input.ContentMD5) {
      headers['content-md5'] = input.ContentMD5;
    }
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-algorithm', input.SSECAlgorithm);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key', input.SSECKey);
    writeHeaders(headers, 'x-tos-server-side-encryption-customer-key-md5', input.SSECKeyMD5);
    const totalSize = getSize(input.Content, headers);
    let consumedBytes = 0;
    const triggerDataTransfer = (
      type: DataTransferType,
      rwOnceBytes: number = 0
    ) => {
      if (totalSize === null) {
        return;
      }
      if (!input.DataTransferListener) {
        return;
      }
      consumedBytes += rwOnceBytes;

      input.DataTransferListener.DataTransferStatusChange({
        Type: type,
        RWOnceBytes: rwOnceBytes,
        ConsumedBytes: consumedBytes,
        TotalBytes: totalSize,
      });
    };
    triggerDataTransfer(DataTransferType.Started);

    const getContent = () => {
      if (input.Content instanceof ArrayBuffer && input.Content.byteLength === 0) {
        return;
      }
      return input.Content;
    }

    const newContent = getContent();

    try {
      const res = await this._fetchObject({
        bucket: input.Bucket,
        key: input.Key
      }, 'PUT', {
        partNumber: input.PartNumber,
        uploadId: input.UploadID
      }, headers, newContent, {
        isStreamReq: input.Content instanceof rcp.UploadFromStream,
        useCustomHttp: true,
        onProgress(size){
          triggerDataTransfer(DataTransferType.RW, size - consumedBytes)
        }
      })
      const output = {
        HashCrc64ecma: res.headers['x-tos-hash-crc64ecma']
      } as UploadPartOutput;
      output.ETag = res.headers.etag ?? "";
      output.PartNumber = input.PartNumber;
      withRequestInfo(output, res);
      triggerDataTransfer(DataTransferType.Succeed);
      return output
    } catch (e) {
      triggerDataTransfer(DataTransferType.Failed);
      throw e as Error
    }

  }
  uploadPartCopy = async (input: UploadPartCopyInput): Promise<UploadPartCopyOutput> => {
    const headers = normalizeHeadersKey(input.RequestHeader) ?? {};
    const query: Query = {}
    query.partNumber = input.PartNumber;
    query.uploadId = input.UploadID;
    let copySource = this.getCopySourceHeader(input.SrcBucket, input.SrcKey);
    if (input.SrcVersionID) {
      copySource += `?versionId=${input.SrcVersionID}`;
    }
    writeHeaders(headers, 'x-tos-copy-source', copySource);
    if (input.CopySourceRange) {
      writeHeaders(headers, 'x-tos-copy-source-range', input.CopySourceRange);
    } else  {
      if (input.CopySourceRangeStart !== undefined || input.CopySourceRangeEnd !== undefined) {
        const start =
          input.CopySourceRangeStart !== undefined ? `${input.CopySourceRangeStart}` : '';
        const end =
          input.CopySourceRangeEnd !== undefined ? `${input.CopySourceRangeEnd}` : '';
        const copyRange = `bytes=${start}-${end}`;
        writeHeaders(headers, 'x-tos-copy-source-range', copyRange);
      }
    }

    const res = await this._fetchObject({
      bucket: input.Bucket,
      key:input.Key
    }, 'PUT', query, headers)
    const output = res.data as UploadPartCopyOutput;
    output.LastModified = new Date(output.LastModified);
    withRequestInfo(output, res);
    return output;
  }
  listParts = async (input: ListPartsInput): Promise<ListPartsOutput> => {
    const res = await this._fetchObject({
      bucket: input.Bucket,
      key: input.Key
    }, 'GET', {
      uploadId: input.UploadId,
      'part-number-marker': input.PartNumberMarker,
      "max-parts": input.MaxParts
    }, {})
    const output = res.data as ListPartsOutput;
    withRequestInfo(output, res);
    if (!output.Parts) {
      output.Parts = [];
    }
    return output;
  }
  completeMultipartUpload = async (input: CompleteMultipartUploadInput): Promise<CompleteMultipartUploadOutput> => {
    const headers: Headers = {};
    writeHeaders(headers, 'x-tos-callback', input.Callback);
    writeHeaders(headers, 'x-tos-callback-var', input.CallbackVar);
    let res: Response
    if (input.CompleteAll) {
      if (input.Parts && input.Parts.length > 0) {
        throw new TosClientError(
          `Should not specify both 'completeAll' and 'parts' params.`
        );
      }
      headers['x-tos-complete-all'] = 'yes'
      res = await this._fetchObject({
        bucket: input.Bucket,
        key: input.Key
      }, 'POST', {
        uploadId: input.UploadID
      }, headers);
    } else {
      const body: PartBody = {
        Parts: input.Parts?.map(item => new Part(item.PartNumber, item.ETag)) ?? []
      }
      res = await this._fetchObject({
        bucket: input.Bucket,
        key: input.Key
      }, 'POST', {
        uploadId: input.UploadID
      }, headers, body);
    }
    let output2: CompleteMultipartUploadOutput;

    if (input.Callback) {
      const output = {
        ETag: res.headers['etag'],
        Location: res.headers['location'],
        Bucket: input.Bucket,
        Key: input.Key,
        VersionID: res.headers['x-tos-version-id']
      } as CompleteMultipartUploadOutput;
      try {
        output.CallbackResult = JSON.stringify(res.data);
      } catch (e) {
        console.log(e);
      }
      output2 = output
    } else {
      output2 = res.data as CompleteMultipartUploadOutput
    }
    withRequestInfo(output2, res)
    output2.HashCrc64ecma = res.headers['x-tos-hash-crc64ecma'];

    return output2;
  }
  abortMultipartUpload = async (input: AbortMultipartUploadInput): Promise<AbortMultipartUploadOutput> => {
    const res = await this._fetchObject(
      {
        bucket: input.Bucket,
        key: input.Key
      },
      'DELETE',
      {
        uploadId: input.UploadID,
      },
      {}
    );
    const output = {} as AbortMultipartUploadOutput;
    withRequestInfo(output, res);
    return output
  }
}