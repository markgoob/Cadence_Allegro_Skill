;2023/10/28 初版

;2024/05/07 Bear.Chou 改版
;新增 > 自動修正疊參數 防止閃退(包含偵測到GND,AGND,DGND時改成PLANE Type)
;新增 > TOP與BOTTOM自檢模式 會自動忽略
;新增 > 偵測到TOP與BOT時計算疊構層數 若為奇數時則跳出警告


axlCmdRegister( "xsec" 'xsec)

procedure( xsec()

axlShell("setwindow pcb")
axlShell("status")
axlShell("generaledit ")
axlShell("setwindow form.status")
axlShell("FORM status fill_wysiwyg NO")
axlShell("FORM status drc_on NO")
axlShell("FORM status done")

TOP_BOT_FIND = ""
TOP_EXSIT = nil
BOTTOM_EXSIT = nil

; 使用者選擇疊構文字檔

	filename = axlDMFileBrowse(nil nil ?title "Chose Xsection file(.txt)" ?optFilters "Text file(*.txt)|*.txt|")
	xsec_list = axlGetXSection()
	i = 0

if(filename != nil then

axlShell("set noconfirm")
axlMsgPut("==============")
axlSaveDesign(?design axlCurrentDesign())
axlShell("unset noconfirm")

	vis = axlVisibleGet()
	org_layerlist = car(list(axlGetParam("paramLayerGroup:ETCH")->groupMembers))

	ex_in = axlDMOpenFile("ALLEGRO_TEXT" filename "r")

	while(gets(extract_data ex_in)			;"L02_DGND\n"
		l_fields = parseString(extract_data)	;("L02_DGND")
		str = car(l_fields)

;如果不是空行則讀取字串

;TOP BOT
		if(str != nil && str != "" && str != axlConductorTopLayer() && str != axlConductorBottomLayer() then
		
;將字串寫入疊構
		
		axlLayerCreateCrossSection("Bottom" "Conductor" "Copper" str)
		axlLayerCreateCrossSection("Bottom" "Dielectric" "FR-4")
		axlPadSuppressSet(nil str '(via pin))
		axlMsgPut("--> Create Layer > %L" str)
		++ i

		else
		
		when(str != nil 
		
		TOP_BOT_FIND = nth(1 parseString(str "_"))
		when(TOP_BOT_FIND == "TOP" TOP_EXSIT = t)
		when(TOP_BOT_FIND == "BOTTOM" BOTTOM_EXSIT = t)
		axlMsgPut("--> Ignore Layer > %L" str)
			
		);END when
			
			);end if

		);end while

;關閉文件
	axlDMClose(ex_in)
	
	axlMsgPut(" Xsection Add Done ! ")
	axlMsgPut("==============")
	axlMsgPut(" Wait for Xsection Value reset ... ")
;釋放暫存
	filename = nil
;呼叫數值修正模組

	xsec_2()

	
	 axlVisibleDesign(nil)
	 axlVisibleSet(vis)
	 axlVisibleUpdate(t)
	 
	 	when(TOP_EXSIT == t && BOTTOM_EXSIT == t && (oddp i) == t
		
		axlUIConfirm(strcat("It Look Like your Xsection are not even ! \n You Should Check It !\n\n" "Layer Count : " sprintf(nil "%L" i) " (Ignore TOP and BOT)") 'warn)
		)
		
)

axlShell("setwindow pcb")
axlShell("status")
axlShell("generaledit ")
axlShell("setwindow form.status")
axlShell("FORM status fill_wysiwyg YES")
axlShell("FORM status drc_on YES")
axlShell("FORM status done")

)

;------------------ 副模組 ----------------

procedure( xsec_2()


;獲取所有層別/疊構資訊
xsec_list = axlGetXSection()
xsec_list_new = nil
xsec_list_length = length(xsec_list)

foreach(s_xsec xsec_list

Layer_name = nth(0 s_xsec)
Layer_Function = nth(1 s_xsec)
Layer_Th_Val = nth(3 s_xsec)

;若疊構後厚度為0則預設成3.90 mil(設啥值都行 不為0就好)
;超過54層則採H oz厚度反之1 oz
when(Layer_Th_Val == "0 mil" 
if(xsec_list_length < 54 then
Layer_Th_Val = "1.38 mil"
else
Layer_Th_Val = "0.71 mil"
)
)


;若疊構類型為"SURFACE" 則不變動
if(Layer_Function == "SURFACE" then
xsec_list_new = cons(s_xsec xsec_list_new)
)

;若疊構類型為"DIELECTRIC" 則修改成FR-4 與 以下數值
when(nth(1 car(xsec_list_new)) != "DIELECTRIC"
if(Layer_Function == "DIELECTRIC" then
xsec_list_new = cons(list("" "DIELECTRIC" "FR-4" Layer_Th_Val "0 w/cm-degC" "0 mho/cm" "4.200000" nil nil "0.02" "" nil nil nil "0.000000")  xsec_list_new)
)
)

;判斷CONDUCTOR名稱 如果是GND就改成PLANE Type
when(Layer_Function == "CONDUCTOR" || Layer_Function == "PLANE"

Layer_name_GND = nth(1 parseString(Layer_name "_"))
Layer_name_GND = pin_ABC(Layer_name_GND)

;axlVisibleDesign(strcat("ETCH/" Layer_name) nil)


if(Layer_name_GND == "GND" || Layer_name_GND == "DGND" || Layer_name_GND == "AGND" || Layer_name_GND == "UGND" then
xsec_list_new = cons(list(Layer_name "PLANE" "COPPER" Layer_Th_Val "0 w/cm-degC" "595900 mho/cm" "4.200000" nil nil "0.02" "" "4.200000" "0.02" nil "90.000000") xsec_list_new)
else
xsec_list_new = cons(list(Layer_name "CONDUCTOR" "COPPER" Layer_Th_Val "0 w/cm-degC" "595900 mho/cm" "4.200000" nil nil "0.02" "" "4.200000" "0.02" nil "90.000000") xsec_list_new)
);IF GND

);WHEN CONDUCTOR PLANE
);FOREACH

xsec_list_new = reverse(xsec_list_new) ;反轉整個list，因為list為先進後出需反轉成先進先出

_fpBioImportXSection(xsec_list_new);把新疊構info寫回
	
	axlMsgPut(" Xsection Value Fix Done ! ")
	axlMsgPut("==============")
	axlShell("xsection")
)


;------------------ 副模組 寫入疊構數值 ----------------

axlCmdRegister( "xsec_val" 'xsec_3)

procedure( xsec_3()

i = 0
filename = nil
filename = axlDMFileBrowse(nil nil ?title "Chose Xsection Value file(.txt)" ?optFilters "Text file(*.txt)|*.txt|")
;獲取所有層別/疊構資訊
xsec_list = axlGetXSection()
xsec_list_new = nil
xsec_value_list = nil


if(filename != nil then

;------------ 讀取數值START ----------

ex_in = axlDMOpenFile("ALLEGRO_TEXT" filename "r")

	while(gets(extract_data ex_in)			;"L02_DGND\n"
		l_fields = parseString(extract_data)	;("L02_DGND")
		str = car(l_fields)

		if(str != nil && str != "" then		
		xsec_value_list = cons(str xsec_value_list)		
				);END IF str nil 
		);END WHILE
		
		xsec_value_list = reverse(xsec_value_list)
		
;------------ 讀取數值END ----------
		
		
		foreach(a_orig_xsec xsec_list
		
		Layer_name = nth(0 a_orig_xsec)
		Layer_Function = nth(1 a_orig_xsec)
		Layer_Type = nth(2 a_orig_xsec)

		Layer_Th_Val = nth(i xsec_value_list)
		
			;若疊構類型為"SURFACE" 則不變動
			if(Layer_Function == "SURFACE" then
			xsec_list_new = cons(a_orig_xsec xsec_list_new)
			)
		
			when(nth(1 car(xsec_list_new)) != "DIELECTRIC"
			if(Layer_Function == "DIELECTRIC" then
			xsec_list_new = cons(list(Layer_name Layer_Function Layer_Type Layer_Th_Val "0 w/cm-degC" "0 mho/cm" "4.20" nil nil "0.02" "" nil nil nil "0.00") xsec_list_new)
			axlMsgPut("--> DIELECTRIC Layer Add Value > %L" Layer_Th_Val)
			++ i
			)
			)

			if(Layer_Function == "CONDUCTOR" || Layer_Function == "PLANE" then
			xsec_list_new = cons(list(Layer_name Layer_Function Layer_Type Layer_Th_Val "0 w/cm-degC" "595900 mho/cm" "4.20" nil nil "0.02" "" "4.20" "0.02" nil "90.00") xsec_list_new)
			axlMsgPut("--> %L Layer Add Value > %L" Layer_name Layer_Th_Val)
			++ i
			)
		
			);END FOREACH
		
		xsec_list_new = reverse(xsec_list_new) ;反轉整個list，因為list為先進後出需反轉成先進先出
		_fpBioImportXSection(xsec_list_new);把新疊構info寫回
		axlShell("xsection")

;關閉文件
	axlDMClose(ex_in)

);filename not nil

)


;------------------ 副模組 rename ----------------

axlCmdRegister( "xsec_rename" 'xsec_4)

procedure( xsec_4()

filename = nil
filename = axlDMFileBrowse(nil nil ?title "Chose Xsection name file(.txt)" ?optFilters "Text file(*.txt)|*.txt|")
;獲取所有層別/疊構資訊
xsec_list = axlGetXSection()
xsec_list_new = nil
xsec_value_list = nil
i = 1
count = 2

ScriptFileName = axlTempFile()
Script_File = axlDMOpenFile("Grid_SCRIPT", ScriptFileName, "w") 
brdname = axlCurrentDesign()
layerlist = car(list(axlGetParam("paramLayerGroup:ETCH")->groupMembers))

if(filename != nil then

;------------ 讀取數值START ----------

ex_in = axlDMOpenFile("ALLEGRO_TEXT" filename "r")

	while(gets(extract_data ex_in)			;"L02_DGND\n"
		l_fields = parseString(extract_data)	;("L02_DGND")
		str = car(l_fields)

		if(str != nil && str != "" && str != "TOP" && str != "BOTTOM" then		
		xsec_value_list = cons(str xsec_value_list)		
		axlMsgPut(" >> %L" str)
				);END IF str nil 
		);END WHILE
		
		xsec_value_list = reverse(xsec_value_list)
		
		
;------------ 讀取數值END ----------
		
		;將生成的netlist資料夾帶回allegro內
fprintf(Script_File "scriptmode +i\n\n")
fprintf(Script_File "setwindow pcb\n")
fprintf(Script_File "trapsize 7593\n")
fprintf(Script_File "generaledit\n")
fprintf(Script_File "xsection\n")
fprintf(Script_File "QtSignal m_dockWsQtWidgetContents m_domainSelector currentChanged\n")
fprintf(Script_File "QtSignal m_dockWsQtWidgetContents m_domainSelector currentChanged Electrical\n")
fprintf(Script_File "QtSignal CCMQtXSectionDlg m_dialogsTab currentChanged Info\n")
fprintf(Script_File "setwindow cmgr \n")
fprintf(Script_File , "cm scope Design %L\n" , brdname)


foreach(a_layer layerlist
i = i + count
fprintf(Script_File , "cm putValue ( Layer \"%L\" ) CDS_LAYER_NAME %L 0\n" , i i)
)

i = 1
count = 2

fprintf(Script_File "\n")
fprintf(Script_File "\n")

foreach(a_xsec_value xsec_value_list

axlMsgPut(" >> rename %L" a_xsec_value)
i = i + count
fprintf(Script_File , "cm putValue ( Layer \"%L\" ) CDS_LAYER_NAME %L 0\n" , i a_xsec_value)
)

fprintf(Script_File "setwindow pcb\n")
fprintf(Script_File "QtSignal CCMQtXSectionDlg m_OkBtn clicked\n" )
fprintf(Script_File "generaledit\n")

axlDMClose(Script_File) 
sprintf(runScript , "replay %s" , ScriptFileName) 
axlShell(runScript)
deleteFile(ScriptFileName)

);filename not nil

)
   


