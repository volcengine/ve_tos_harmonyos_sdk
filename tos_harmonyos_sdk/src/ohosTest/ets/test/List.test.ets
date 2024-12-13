/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import bucketTest from './bucket.test'
import bucketEncryptionTest from './bucketEncryption.test'
import bucketMirrorBackTest from './bucketMirrorBack.test'
import putObjectTest from './putObject.test'
import putObjectTest2 from './putObject2.test'
import copyObjectTest from './copyObject.test';
import multiObjectsTest from './multiObjects.test'
import clearBucketTest from './clearBuckets.test'
import headObjectTest from './headObject.test'
import preSignedURLTest from './preSignedURL.test'
import preSignedPolicyURLTest from './preSignedPolicyURL.test'
import preSignedPostSignatureTest from './preSignedPostSignature.test'
import fetchObjectTest from './fetchObject.test'
import fetchTaskTest from './fetchTask.test'
import fileTest from './file.test'
import partsTest from './parts.test'
import uploadPartsTest from './uploadParts.test'
import appendObjectTest from './appendObject.test'
import uploadPartCopyTest from './uploadPartCopy.test'
import streamTest from './stream.test'
import httpSchemeTest from './httpScheme.test'
import encodeTest from './encode.test'

export default function testsuite() {
  bucketTest()
  bucketEncryptionTest();
  bucketMirrorBackTest();
  putObjectTest();
  putObjectTest2();
  copyObjectTest();
  multiObjectsTest();
  clearBucketTest();
  headObjectTest();
  fetchObjectTest();
  fetchTaskTest();
  preSignedURLTest();
  preSignedPolicyURLTest();
  preSignedPostSignatureTest();
  fileTest();
  partsTest();
  uploadPartsTest();
  appendObjectTest();
  uploadPartCopyTest();
  streamTest();
  httpSchemeTest();
  encodeTest();
}