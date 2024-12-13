/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

export interface Any {}

export type Headers = Record<string, string |undefined>;

export interface Query extends Record<string, string | undefined | number>{
  location?: string;
  tagging?: string;
  mirror?: string;
  versioning?: string;
  versions?: string;
  'list-type'?: number;
  delimiter?: string;
  'encoding-type'?: string;
  'max-keys'?: number;
  prefix?: string;
  'start-after'?: string;
  'fetch-owner'?: string;
  'continuation-token'?: string;
  acl?: string;
  versionId?: string;
  uploads?: string
  partNumber?: number;
  uploadId?: string;
  encryption?: string
  'max-uploads'?: number;
  'key-marker'?: string;
  'upload-id-marker'?: string
  'max-parts'?: number;
  'part-number-marker'?: number;
  metadata?: string,
  fetch?: string
  fetchTask?: string
  taskId?: string
}

export type Method = 'GET' | 'DELETE' | 'HEAD' | 'OPTIONS' | 'POST' | 'PUT' | 'PATCH'

export class  Response {
  headers: Headers
  status: number
  data?: Any

  constructor(status: number, headers: Headers, data?: Any) {
    this.status = status;
    this.headers = headers
    this.data = data;
  }
}

export class Part {
  PartNumber: number;
  ETag: string;
  constructor(PartNumber: number, ETag: string) {
    this.PartNumber = PartNumber;
    this.ETag = ETag;
  }
}

export interface PartBody {
  Parts: Part[]
}
