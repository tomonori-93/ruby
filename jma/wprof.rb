#!/usr/bin/ruby
# Author: Satoki Tsujino (satoki@gfd-dennou.org)
# Date  : 2023/12/13
# Update:  
# License: MIT (see LICENSE.md)
# [USAGE] : ruby wprof.rb input_fname
# [NOTE] : the output file name is named from information in the original file. 
# [Reference1]: https://www.data.jma.go.jp/add/suishin/jyouhou/pdf/97.pdf
# [Reference2]: https://www.nco.ncep.noaa.gov/sib/jeff/bufrtab_tableb.html

def conv_oct_tobyte( inv )
   # Convert any octets variables to a single byte variable
   # inv: N integers for unsigned 8 bits
   nsize = inv.size
   #puts "check, #{nsize}, #{inv}"

   if(nsize==1)then
      return inv
   end

   val = 0
   for nn in 0..nsize-2
      val = val + inv[nn]<<(nsize-1-nn)*8
   end
   val = val + inv[nsize-1]  # bit shifting
   return val
end

def conv_2oct_to268( inv )
   # Convert two 8 bits variables to a character "X-XX-XXX"
   # 16bits -> 2bits-6bits-8bits
   nsize = inv.size

   if(nsize!=2)then
      puts "ERROR (conv_2oct_to268): Invalid inputs."
      exit
   end

   tval2 = inv[0]>>6  # 右に 6 bits シフト (先頭 2 bits 取り出し)
   tval6 = inv[0] - (tval2<<6)  # 先頭 2 bits をゼロ化
   tval8 = inv[1]

   cval = tval2.to_s.rjust(1,"0") + "-" + tval6.to_s.rjust(2,"0") + "-" + tval8.to_s.rjust(3,"0")

   return cval
end

def conv_octs_toi( inv, str_num, length )
   # Convert any unsigned single variavles to an integer
   # str_num  = the bit position from the left in inv[0] (from 0).
   #            The left one is located at the bit position of 0
   # length = the bit length for the converted integer
   # やり方は inv をビットシフトで全結合し, 必要ビット列のみを以下でフィルタする
   # [前提]: inv の全結合 (inv_fin, ビット数 inv.size * 8)
   #         例: str_num = 2, length = 3 の場合,
   #             inv_fin = "00101001" -> "00000101" = result
   # [フィルタの作り方]: 
   # 1. inv.size * 8 で全て 1 が立った整数 (int_flt) を用意する.
   #    例: int_flt = "11111111"
   # 2. 必要ビット列をゼロにする.
   #    コンセプトは int_flt を右にシフトさせて左シフトで元の位置に戻すことで
   #    必要ビット列をゼロ埋めしたフィルタ int_flt を作る.
   # 2.1 int.size * 8 - str_num 分右にシフトさせて同じだけもとに戻す.
   #     -> 左側に 1 が立ったビットが生成 (int_flt_left)
   #     例: int_flt = "11111111" -> "11000000" = int_flt_left
   # 2.2 int.size * 8 - (str_num + length) 分右にシフトさせて同じだけもとに戻し,
   #     int_flt から引く -> 右側に 1 が立ったビットが生成 (int_flt_right)
   #     例: int_flt = "11111111" -> "00000111" = int_flt_right
   # 2.3 int_flt = int_flt_left + int_flt_right でフィルタ完成
   #     例: int_flt = "11000000" + "00000111" = "11000111"
   # 3. inv_fin と int_flt の OR をとる
   #    -> inv_fin のうち, int_flt で 1 が立ったビット列は全て 1 が立っている
   #       (inv_fin_and) 
   #     例: inv_fin_and = "00101001" & "11000111" = "11101111"
   # 4. inv_fin_and から int_flt を引く (inv_fin_flt)
   #    例: inv_fin_flt = "11101111" - "11000111" = "00101000"
   # 5. 再度 int.size * 8 - (str_num + length) 分右にシフト inv_fin_flt を
   #    右にシフト (result)
   #    例: result = "00101000" -> "00000101"

   nsize = inv.size
   totoct = 8 * nsize

   if(nsize == 0)then
      puts "ERROR (conv_octs_toi): Invalid inputs."
      exit
   end

   inv_fin = inv[0]<<(8*(nsize-1))

   if nsize > 1 then
      for i in 1..nsize-1
         inv_fin = inv_fin + (inv[i]<<(8*(nsize-i-1)))
      end
   end

#puts "check1, #{inv_fin}, #{nsize}"
   # 1. inv.size * 8 で全て 1 が立った整数 (int_flt) を用意する.
   int_flt = 2**totoct - 1

   # 2. 必要ビット列をゼロにする.
   # 2.1 int.size * 8 - str_num 分右にシフトさせて同じだけもとに戻す.
   int_flt_left = (int_flt>>(totoct-str_num))<<(totoct-str_num)

   # 2.2 int.size * 8 - (str_num + length) 分右にシフトさせて同じだけもとに戻し,
   #     int_flt から引く -> 右側に 1 が立ったビットが生成 (int_flt_right)
   int_flt_right = int_flt - ((int_flt>>(totoct-(str_num+length)))<<(totoct-(str_num+length)))
   
   # 2.3 int_flt = int_flt_left + int_flt_right でフィルタ完成
   int_flt = int_flt_left + int_flt_right

   # 3. inv_fin と int_flt の OR をとる
   inv_fin_and = inv_fin | int_flt

#puts "checkand, #{int_flt}, #{inv_fin}, #{inv_fin_and}"
   # 4. inv_fin_and から int_flt を引く (inv_fin_flt)
   inv_fin_flt = inv_fin_and - int_flt

   # 5. 再度 int.size * 8 - (str_num + length) 分右にシフト inv_fin_flt を
   #    右にシフト (result)
   result = inv_fin_flt>>(totoct-(str_num+length))

#puts "res = #{result}"
   return result
end

if ARGV.size != 1 then
   puts '[USAGE] : ruby wprof.rb input_filename'
   exit
end

ifile = ARGV[0]

puts "Input #{ifile}..."

f = open(ifile,'rb')
fsize = File.size(ifile)
m = f.read(fsize)

sec_head = ["A18"]
sec0 = ["A4", "C3", "C"]
clist = sec_head.join + sec0.join  # sec0 の各配列要素文字列を結合
iupcnum = m.unpack(clist)[0][4..5]
#puts clist, m.unpack(clist)[0..1]
#puts conv_oct_tobyte( m.unpack(clist)[2..4] )  # sec0[2] == "C3" = "CCC"
#puts m.unpack(clist)[5]
puts "File Header = #{m.unpack(clist)[0]}"
puts "File Format = #{m.unpack(clist)[1]}#{m.unpack(clist)[5]}"
puts "File length = #{conv_oct_tobyte( m.unpack(clist)[2..4] )}"
tot_length = m.unpack(clist)[0..1]  # ファイルの長さ (ヘッダ 18 bytes 除く)

sec1 = ["C3", "C", "C2", "C2", "C", "C", "C", "C", "C", "C", "C", "C2", "C", "C", "C", "C", "C"]
clist = clist + sec1.join
#puts conv_oct_tobyte( m.unpack(clist)[6..8] )  # sec1[0] == "C3" = "CCC"
#puts m.unpack(clist)[9]
#puts conv_oct_tobyte( m.unpack(clist)[10..11] )  # sec1[2] == "C2" = "CC"
#puts conv_oct_tobyte( m.unpack(clist)[12..13] )  # sec1[3] == "C2" = "CC"
#puts m.unpack(clist)[14..20]
#puts conv_oct_tobyte( m.unpack(clist)[21..22] )  # sec1[12] == "C2" = "CC"
#puts m.unpack(clist)[23..27]
sec1_length = conv_oct_tobyte( m.unpack(clist)[6..8] )

sec3 = ["C3", "C", "C2", "C", "C48"]  # "C48" == "C2" * 24
clist = clist + sec3.join
#puts conv_oct_tobyte( m.unpack(clist)[28..30] )  # sec3[0] == "C3" = "CCC"
#puts m.unpack(clist)[31]
#puts conv_oct_tobyte( m.unpack(clist)[32..33] )  # sec3[2] == "C2" = "CC"
#puts m.unpack(clist)[34]
#for i in 0..23
#   puts conv_2oct_to268( m.unpack(clist)[35+i*2..35+i*2+1] )
#end
sec3_length = conv_oct_tobyte( m.unpack(clist)[28..30] )

sec4h = ["C3", "C"]
clist = clist + sec4h.join
#puts conv_oct_tobyte( m.unpack(clist)[83..85] )
sec4_length = conv_oct_tobyte( m.unpack(clist)[83..85] )
sec4 = ["C#{sec4_length.to_i-4}"]  # 残りを一括で 1 byte 整数として読み込む
                                   # -4 は sec4h で読み込んだ 4 byte
sec5 = ["A4"]
clist = clist + sec4.join + sec5.join

#-- Parameters for BUFR4 format
              # WMO block, WMO loc, lat, lon, obs height, 6, x_itr
length_head = [7, 10, 15, 16, 15, 4, 8]
scale_head  = [1, 1, 0.01, 0.01, 1.0, 1.0, 1, 1]
reference_head = [0, 0, -9000, -18000, -400, 0, 0]
head_name = ["WMO block", "WMO location", "Latitude", "Longitude", "OBS Height", "Measure", "OBS count"]

           # yyyy, mm, dd, hh, nn, time, period, y_itr
length_x = [12, 4, 6, 5, 6, 5, 12, 8]
scale_x  = [1, 1, 1, 1, 1, 1, 1, 1]
reference_x = [0, 0, 0, 0, 0, 0, -2048, 0]

           # obs Z, QC, U, V, W, SN
length_y = [15, 8, 13, 13, 13, 8]
scale_y  = [1.0, 1, 0.1, 0.1, 0.01, 1.0]
reference_y = [0, 0, -4096, -4096, -4096, -32]

#-- Parameters for wind profiler data (location number)
iupc_ii = {"41"=>3, "42"=>4, "43"=>3, "44"=>3, "45"=>3, "46"=>4, "47"=>3, "48"=>4, "49"=>3, "50"=>3}

head_val = Array.new(length_head.size)

cnt_str_num = 0
str_clist = 0
cnt_length = 0
end_clist = 0

for k in 1..iupc_ii[iupcnum]
   #-- WMO block
   if k == 1 then
      cnt_str_num = 0
      str_clist = 87
   else
      cnt_str_num = (cnt_str_num + cnt_length) % 8
      str_clist = end_clist
   end
   cnt_length = length_head[0]
   end_clist = str_clist + (cnt_length + cnt_str_num) / 8
   if (cnt_length + cnt_str_num) % 8 == 0 then
      end_clist = end_clist - 1
   end
   wmo_block = conv_octs_toi( m.unpack(clist)[str_clist..end_clist], str_num=cnt_str_num, length=cnt_length )
   if (cnt_length + cnt_str_num) % 8 == 0 then
      end_clist = end_clist + 1
   end

   #-- read in head
   for i in 1..length_head.size-1
      cnt_str_num = (cnt_str_num + cnt_length) % 8
      cnt_length = length_head[i]
      str_clist = end_clist
      end_clist = str_clist + (cnt_length + cnt_str_num) / 8
      if (cnt_length + cnt_str_num) % 8 == 0 then
         end_clist = end_clist - 1
      end
   #puts "checkk #{str_clist}, #{end_clist}, #{cnt_str_num}, #{cnt_length}"
      head_val[i] = conv_octs_toi( m.unpack(clist)[str_clist..end_clist], str_num=cnt_str_num, length=cnt_length )
      head_val[i] = (head_val[i] + reference_head[i]) * scale_head[i]
      puts "#{head_name[i]} = #{head_val[i]}"
      if (cnt_length + cnt_str_num) % 8 == 0 then
         end_clist = end_clist + 1
      end
   end

   x_itr = head_val[-1].to_i
   x_val = Array.new(length_x.size * x_itr)  # x 要素 * 反復回数

   #-- read in data
   for ix in 0..x_itr-1
      for jx in 0..length_x.size-1
         cnt_str_num = (cnt_str_num + cnt_length) % 8
         cnt_length = length_x[jx]
         str_clist = end_clist
         end_clist = str_clist + (cnt_length + cnt_str_num) / 8
         if (cnt_length + cnt_str_num) % 8 == 0 then
            end_clist = end_clist - 1
         end
         tmp_val = conv_octs_toi( m.unpack(clist)[str_clist..end_clist], str_num=cnt_str_num, length=cnt_length )
         x_val[jx+length_x.size*ix] = (tmp_val + reference_x[jx]) * scale_x[jx]
   #puts "x (#{jx}, #{ix}) = #{x_val[jx+length_x.size*ix]}"
         if (cnt_length + cnt_str_num) % 8 == 0 then
            end_clist = end_clist + 1
         end
      end

      ctime = x_val[0+length_x.size*ix].to_s.rjust(4,"0") + x_val[1+length_x.size*ix].to_s.rjust(2,"0") + x_val[2+length_x.size*ix].to_s.rjust(2,"0") + x_val[3+length_x.size*ix].to_s.rjust(2,"0") + x_val[4+length_x.size*ix].to_s.rjust(2,"0")
      cout = "OBS point (lon, lat, height): #{head_val[3]}, #{head_val[2]}, #{head_val[4]}\n"
      cout = cout + "OBS time (yyyymmddhhnn): #{ctime}\n"
      cout = cout + "Height, U-wind, V-wind, W-wind\n"
      cout = cout + "m,      ms-1,   ms-1,   ms-1  \n"
    
      ofile = ifile + "_" + (head_val[0]).to_s + (head_val[1]).to_s + "_" + ctime + ".csv"
      g = open(ofile,"w")

      y_itr = x_val[length_x.size-1+length_x.size*ix].to_i
      y_val = Array.new(length_y.size*y_itr)  # y 要素 * 反復回数
      for iy in 0..y_itr-1
         for jy in 0..length_y.size-1
            cnt_str_num = (cnt_str_num + cnt_length) % 8
            cnt_length = length_y[jy]
            str_clist = end_clist
            end_clist = str_clist + (cnt_length + cnt_str_num) / 8
            if (cnt_length + cnt_str_num) % 8 == 0 then
               end_clist = end_clist - 1
            end
            #puts "checkk #{str_clist}, #{end_clist}, #{cnt_str_num}, #{cnt_length}"
            tmp_val = conv_octs_toi( m.unpack(clist)[str_clist..end_clist], str_num=cnt_str_num, length=cnt_length )
            if length_y[jy] == 13 then  # データ部
               if tmp_val == (2**13-1) then  # 全ビットが 1
                  y_val[jy+length_y.size*iy] = tmp_val.to_f
               else
                  y_val[jy+length_y.size*iy] = (tmp_val + reference_y[jy]) * scale_y[jy]
               end
            else
               y_val[jy+length_y.size*iy] = (tmp_val + reference_y[jy]) * scale_y[jy]
            end
            #puts "y (#{jy},#{iy}) = #{y_val[jy+length_y.size*iy]}"
            if (cnt_length + cnt_str_num) % 8 == 0 then
               end_clist = end_clist + 1
            end
         end

         if y_val[1+length_y.size*iy] == 2**7 then  # "10000000"
            cout = cout + "#{y_val[0+length_y.size*iy]}, #{y_val[2+length_y.size*iy]}, #{y_val[3+length_y.size*iy]}, #{y_val[4+length_y.size*iy]}\n"
         end

      end

      g.write(cout[0..-2])
      g.close
      puts "Outputs file: #{ofile}"

   end
end

puts "check fin #{end_clist} #{m.unpack(clist).size}"
