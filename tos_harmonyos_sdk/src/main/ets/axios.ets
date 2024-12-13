/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import axios from '@ohos/axios';

export const makeAxiosInst = () => {
  const axiosInst = axios.create();
  return axiosInst;
}