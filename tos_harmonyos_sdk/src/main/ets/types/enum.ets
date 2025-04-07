/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

export enum ACLType {
  ACLPrivate = 'private',
  ACLPublicRead = 'public-read',
  ACLPublicReadWrite = 'public-read-write',
  ACLAuthenticatedRead = 'authenticated-read',
  ACLBucketOwnerRead = 'bucket-owner-read',
  ACLBucketOwnerFullControl = 'bucket-owner-full-control',
  // only works for object ACL
  ACLBucketOwnerEntrusted = 'bucket-owner-entrusted',
}

export  enum StorageClassType {
  StorageClassStandard = 'STANDARD',
  StorageClassIa = 'IA',
  StorageClassArchiveFr = 'ARCHIVE_FR',
  StorageClassColdArchive = 'COLD_ARCHIVE',
  StorageClassIntelligentTiering = 'INTELLIGENT_TIERING',
  StorageClassArchive = 'ARCHIVE',
}

export enum AzRedundancyType {
  AzRedundancySingleAz = 'single-az',
  AzRedundancyMultiAz = 'multi-az',
}

export enum BucketType {
  BucketTypeFNS = "fns",
  BucketTypeHNS = "hns"
}

export enum RedirectType {
  RedirectTypeMirror = "Mirror",
  RedirectTypeAsync = "Async"
}

export enum VersioningStatusType {
  VersioningStatusEnabled = 'Enabled',
  VersioningStatusSuspended = 'Suspended',
  VersioningStatusNotSet = 'NotSet',
}

export enum MetadataDirectiveType{
  MetadataDirectiveCopy = 'COPY',
  MetadataDirectiveReplace = 'REPLACE',
}

export enum UploadEventType {
  CreateMultipartUploadSucceed = 'CreateMultipartUploadSucceed',
  CreateMultipartUploadFailed = 'CreateMultipartUploadFailed',
  UploadPartSucceed = 'UploadPartSucceed',
  UploadPartFailed = 'UploadPartFailed',
  UploadPartAborted = 'UploadPartAborted',
  CompleteMultipartUploadSucceed = 'CompleteMultipartUploadSucceed',
  CompleteMultipartUploadFailed = 'CompleteMultipartUploadFailed',
}