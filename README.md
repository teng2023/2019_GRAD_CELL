# 2019_GRAD_CELL (2019 IC競賽 研究所 初賽)

## 題目說明

## 檔案介紹

Pattern (在資料夾dat_grad內)：

Input data (一張64*64bits的灰階圖片)：**cnn_sti.dat**. 

每層Memory的答案：**cnn_layer0_exp0.dat**, **cnn_layer0_exp1.dat**, **cnn_layer1_exp0.dat**, **cnn_layer1_exp1.dat**, **cnn_layer2_exp.dat**. 

Convolution的weight跟bias：**cnn_weight0.dat**, **cnn_bias0.dat**.

Original file：**CONV.v** 

Test Bench：**testfixture.v**

### *Pass the test bench simulation*

**CONV_v1.v**：使用直接計算40個點與圓心的距離。
