/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { StorageClassType } from "./enum";
import { rcp } from "@kit.RemoteCommunicationKit";

export interface InnerHeadObjectOutput {
  ETag: string;
  VersionID?: string;
  ContentLength: number
  ContentType: string;
  CacheControl?: string;
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  Expires?: Date;
  StorageClass: StorageClassType,
  Meta?: Record<string, string>,
  SSECAlgorithm?: string;
  SSECKeyMD5?: string;
  HashCrc64ecma?: string;
}

export interface InnerGetObjectBasicOutput {
  ETag: string;
  ContentRange?: string;
  LastModified?: Date;
  DeleteMarker?: boolean;
  SSECAlgorithm?: string;
  SSECKeyMD5?: string;
  VersionID?: string;
  StorageClass?: StorageClassType
  Meta?: Record<string, string>,
  ContentLength: number
  ContentType: string;
  CacheControl?: string;
  ContentDisposition?: string;
  ContentEncoding?: string;
  ContentLanguage?: string;
  Expires?: Date;
  HashCrc64ecma?: string
}

export interface  InnerGetObjectOutput extends InnerGetObjectBasicOutput {
  Content: rcp.WriteStream;
}

export  interface CheckpointRecordPart {
  part_number: number;
  part_size: number;
  offset: number;
  etag: string;
  hash_crc64ecma: string;
  is_completed: boolean;
}

interface FileInfo {
  last_modified: number;
  file_size: number;
}

export interface CheckpointRecord {
  bucket: string;
  key: string;
  part_size: number;
  upload_id: string;
  parts_info?: CheckpointRecordPart[];
  file_info: FileInfo;
}

export interface CheckpointRichInfo<T> {
  filePath?: string | undefined;
  filePathIsPlaceholder?: boolean;
  record?: T;
}

export interface Task {
  partSize: number;
  offset: number;
  partNumber: number;
}

export interface ObjectInfo {
  etag: string;
  hash_crc64ecma: string;
  object_size: number;
  last_modified: string;
}

export interface DownloadFileInfo {
  file_path: string;
  temp_file_path?: string;
}

export interface DownloadFileCheckpointRecordPartInfo {
  part_number: number;
  range_start: number;
  range_end: number;
  hash_crc64ecma: string;
  is_completed: boolean;
}

export interface DownloadFileCheckpointRecord {
  bucket: string;
  key: string;
  version_id?: string;
  part_size: number;
  object_info: ObjectInfo;
  file_info: DownloadFileInfo;
  parts_info: DownloadFileCheckpointRecordPartInfo[];
}

export interface DownloadFileCheckpointRichInfo{
  filePath?: string | undefined;
  filePathIsPlaceholder?: boolean;
  record?: CheckpointRecord;
}