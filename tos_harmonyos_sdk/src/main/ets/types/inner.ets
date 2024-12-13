/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { StorageClassType } from "./enum";

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