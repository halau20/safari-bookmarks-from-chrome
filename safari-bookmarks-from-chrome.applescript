-- Chrome のブックマークで Safari のブックマークを置き換える（v14・完成版）
--
-- やること（「実行する」を選んだ場合）
--   1. Safari の「ブックマークを編集」で、ブックマークをすべて削除する
--      （「お気に入り」「タブグループのお気に入り」の枠そのものは残し、中身だけ消します）
--   2. Chrome を終了する（読み込みシートは Chrome が起動中だと押せないため）
--   3. 「ファイル > ブラウザから読み込む > Google Chrome」でブックマークだけを読み込む
--   4. Chrome を再起動する（実行前に起動していた場合のみ）
--
-- 「確認だけ」を選ぶと、削除対象の一覧を作って選択するだけで、削除も Chrome の終了もしません。
--
-- 事前準備: スクリプトエディタに「アクセシビリティ」の許可が必要です（許可済みなら不要）。
-- ★実行前に「ファイル > ブラウズデータをファイルに書き出す…」でバックアップを取ってください。

property outText : ""
property importHistory : false -- true にすると履歴も読み込みます
property chromeWasRunning : false -- 実行前に Chrome が起動していたか（終了後に戻すかどうかの判断用）
property specialNames : {"お気に入り", "タブグループのお気に入り"}

on logLine(t)
	set outText to outText & t & linefeed
end logLine

-- 行のテキスト先頭（" / " の前）を取り出す
on rowName(t)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to " / "
	set nm to text item 1 of t
	set AppleScript's text item delimiters to oldDelims
	return nm
end rowName

-- 行の中のテキストを集める
on cellTexts(r)
	set s to ""
	tell application "System Events"
		repeat with cellEl in (UI elements of r)
			try
				repeat with tEl in (UI elements of cellEl)
					set v to ""
					try
						set vv to value of tEl
						if vv is not missing value then set v to vv as text
					end try
					if v is "" then
						try
							set nn to name of tEl
							if nn is not missing value then set v to nn as text
						end try
					end if
					if v is not "" then set s to s & v & " / "
				end repeat
			end try
		end repeat
	end tell
	return s
end cellTexts

on clickTwoLevel(topNames, itemNames)
	tell application "System Events"
		tell process "Safari"
			repeat with t in topNames
				if exists menu bar item (contents of t) of menu bar 1 then
					set theMenu to menu 1 of menu bar item (contents of t) of menu bar 1
					repeat with n in itemNames
						if exists menu item (contents of n) of theMenu then
							click menu item (contents of n) of theMenu
							return true
						end if
					end repeat
				end if
			end repeat
		end tell
	end tell
	return false
end clickTwoLevel

-- ファイルメニューの中から、サブメニュー内の「Google Chrome…」を番号で探してクリック
-- Chrome を終了した直後は「ブラウザから読み込む」のサブメニューが作り直し中で読めないことがあるため、
-- 失敗したら2秒待って最大8回やり直す
on clickImportChromeByIndex()
	repeat with attempt from 1 to 8
		try
			-- 3回目以降は、実際にメニューを開いてサブメニューを表示させてから読む
			if attempt ≥ 3 then my openImportMenuVisibly()
			if my tryClickImportChrome() then return true
			my logLine("読み込みメニュー: Google Chrome が見つかりません（" & attempt & "回目）")
		on error e
			my logLine("読み込みメニュー: 読み取りエラー（" & attempt & "回目）: " & e)
		end try
		my closeMenus()
		delay 2
	end repeat
	return false
end clickImportChromeByIndex

-- 「ファイル」メニューを実際に開き、「ブラウザから読み込む」にポインタを合わせてサブメニューを出す
on openImportMenuVisibly()
	tell application "Safari" to activate
	delay 0.5
	tell application "System Events"
		tell process "Safari"
			click menu bar item "ファイル" of menu bar 1
			delay 0.8
			set fileMenu to menu 1 of menu bar item "ファイル" of menu bar 1
			repeat with i from 1 to count of menu items of fileMenu
				set nm to ""
				try
					set nm to name of menu item i of fileMenu
				end try
				if nm is not missing value and nm contains "ブラウザから読み込む" then
					try
						click menu item i of fileMenu
					end try
					delay 1.2
					exit repeat
				end if
			end repeat
		end tell
	end tell
end openImportMenuVisibly

-- 開いたままのメニューがあれば Esc で閉じる（読み込みシートが出ていれば何もしない）
on closeMenus()
	if my sheetCount() > 0 then return
	tell application "System Events"
		tell process "Safari"
			try
				key code 53
				delay 0.2
				key code 53
			end try
		end tell
	end tell
end closeMenus

on tryClickImportChrome()
	tell application "System Events"
		tell process "Safari"
			repeat with t in {"ファイル", "File"}
				if exists menu bar item (contents of t) of menu bar 1 then
					set fileMenu to menu 1 of menu bar item (contents of t) of menu bar 1
					set n1 to count of menu items of fileMenu
					repeat with i from 1 to n1
						set mi to menu item i of fileMenu
						set hasSub to false
						try
							set hasSub to ((count of menus of mi) > 0)
						end try
						if hasSub then
							set subMenu to menu 1 of mi
							set n2 to count of menu items of subMenu
							repeat with j from 1 to n2
								set sj to menu item j of subMenu
								set nm to missing value
								try
									set nm to name of sj
								end try
								if nm is not missing value then
									if nm starts with "Google Chrome" then
										click sj
										return true
									end if
								end if
							end repeat
						end if
					end repeat
					exit repeat
				end if
			end repeat
		end tell
	end tell
	return false
end tryClickImportChrome

on sheetCount()
	tell application "System Events"
		tell process "Safari"
			try
				return count of sheets of window 1
			on error
				return 0
			end try
		end tell
	end tell
end sheetCount

-- Chrome の起動確認・終了・再起動
on chromeRunning()
	try
		do shell script "pgrep -x 'Google Chrome'"
		return true
	on error
		return false
	end try
end chromeRunning

on quitChrome()
	if not my chromeRunning() then
		my logLine("Chromeは起動していません")
		return
	end if
	tell application id "com.google.Chrome" to quit
	repeat 30 times
		delay 1
		if not my chromeRunning() then
			my logLine("Chromeを終了しました")
			return
		end if
	end repeat
	error "Chromeが30秒たっても終了しません。Chromeの画面を確認してください。"
end quitChrome

on relaunchChrome()
	if not chromeWasRunning then
		my logLine("Chromeは最初から起動していなかったので、再起動しません")
		return
	end if
	if my chromeRunning() then
		my logLine("Chromeは起動したままです（終了する前に止まったため）")
		return
	end if
	try
		do shell script "open -a 'Google Chrome' --args --restore-last-session"
		my logLine("Chromeを再起動しました")
	end try
end relaunchChrome

-- ブックマーク編集画面の一覧（アウトライン）
on getOutline()
	tell application "System Events"
		tell process "Safari"
			return outline 1 of scroll area 1 of group 1 of tab group 1 of splitter group 1 of window 1
		end tell
	end tell
end getOutline

-- 「お気に入り」「タブグループのお気に入り」を展開する
on expandContainers(ol)
	repeat with nmRef in (my specialNames)
		set targetName to contents of nmRef
		tell application "System Events"
			set rc to my rowCount(ol)
			repeat with i from 1 to rc
				set r to row i of ol
				set lvl to -1
				try
					set lvl to (value of attribute "AXDisclosureLevel" of r) as integer
				end try
				if lvl is 0 then
					set t to my cellTexts(r)
					if my rowName(t) is targetName then
						try
							set value of attribute "AXDisclosing" of r to true
						end try
						exit repeat
					end if
				end if
			end repeat
		end tell
	end repeat
	delay 0.8
	-- タブグループごとのフォルダ（タブグループのお気に入りの直下）も展開する。
	-- 展開すると行が増えるので、毎回行数を読み直しながら進む
	set inTG to false
	set i to 1
	repeat while i ≤ (my rowCount(ol))
		tell application "System Events"
			set r to row i of ol
			set lvl to -1
			try
				set lvl to (value of attribute "AXDisclosureLevel" of r) as integer
			end try
		end tell
		if lvl is 0 then
			set inTG to ((my rowName(my cellTexts(r))) is "タブグループのお気に入り")
		else if inTG and lvl is 1 then
			tell application "System Events"
				try
					if (value of attribute "AXDisclosing" of r) is false then set value of attribute "AXDisclosing" of r to true
				end try
			end tell
		end if
		set i to i + 1
	end repeat
	delay 0.5
end expandContainers

-- 削除対象の行を集める。戻り値: {対象の行のリスト, 一覧の文字列, 総行数, 空でない枠の数}
on collectTargets(ol)
	-- 先に、行の参照・階層・テキストを集める（System Events の中ではそれだけをする）
	set allRows to {}
	set lvls to {}
	set texts to {}
	tell application "System Events"
		set rc to my rowCount(ol)
		repeat with i from 1 to rc
			set r to row i of ol
			set lvl to 0
			try
				set lvl to (value of attribute "AXDisclosureLevel" of r) as integer
			end try
			set end of allRows to r
			set end of lvls to lvl
			set end of texts to (my cellTexts(r))
		end repeat
	end tell
	-- 判定は System Events の外で行う
	set selList to {}
	set summary to ""
	set containerBad to 0
	set containerIdx to {}
	-- 「タブグループのお気に入り」直下のフォルダは各タブグループに付いたもので、消せない（v7 のログ）。
	-- 枠として扱い、フォルダそのものは残して中身だけ消す
	set inTG to false
	repeat with i from 1 to rc
		set lvl to item i of lvls
		set t to item i of texts
		set isContainer to false
		if lvl is 0 then
			set inTG to ((my rowName(t)) is "タブグループのお気に入り")
			if specialNames contains (my rowName(t)) then set isContainer to true
		else if inTG and lvl is 1 then
			set isContainer to true
		end if
		if isContainer then
			set end of containerIdx to i
			-- 「タブグループのお気に入り」自体は、消せないタブグループのフォルダを含むので数えない
			if (my rowName(t)) is not "タブグループのお気に入り" then
				if (t contains "項目") and not (t contains " / 0項目") then set containerBad to containerBad + 1
			end if
		else
			set end of selList to i
			set summary to summary & "    行" & i & "（階層" & lvl & "）: " & (my shorten(t)) & linefeed
		end if
	end repeat
	return {selList, summary, rc, containerBad, containerIdx}
end collectTargets

on shorten(t)
	if (length of t) > 60 then return (text 1 thru 60 of t)
	return t
end shorten

-- 数字のリストを「1 2 3」の形の文字にする
on joinInts(lst)
	set s to ""
	repeat with x in lst
		set s to s & (contents of x) & " "
	end repeat
	return s
end joinInts

-- 2つの数字のリストが、順番を問わず同じ内容か
on sameSet(a, b)
	if (count of a) is not (count of b) then return false
	repeat with x in a
		if b does not contain (contents of x) then return false
	end repeat
	return true
end sameSet

-- いま選ばれている行の番号
on selectedIndexes(ol)
	set out to {}
	tell application "System Events"
		set rc to my rowCount(ol)
		repeat with i from 1 to rc
			try
				if (value of attribute "AXSelected" of row i of ol) is true then set end of out to i
			end try
		end repeat
	end tell
	return out
end selectedIndexes

on clearSelection(ol)
	tell application "System Events"
		set rc to my rowCount(ol)
		repeat with i from 1 to rc
			try
				set value of attribute "AXSelected" of row i of ol to false
			end try
		end repeat
	end tell
	delay 0.3
end clearSelection

-- 削除対象の行（targetIdx）だけが選ばれた状態にする。3つの方法を順に試し、
-- 検証に通った方法の名前を返す。全部だめなら "" を返す
on selectTargets(ol, targetIdx, containerIdx)
	-- 先に Safari を最前面にして、一覧にキーボードの操作先を当てる
	tell application "Safari" to activate
	delay 0.5
	tell application "System Events"
		try
			set frontmost of process "Safari" to true
		end try
		try
			set value of attribute "AXFocused" of ol to true
		end try
		try
			set fm to name of first application process whose frontmost is true
			my logLine("最前面のアプリ: " & fm)
		end try
	end tell
	delay 0.5
	-- 方法1: 「すべてを選択」→ 枠の行だけ選択解除
	my clearSelection(ol)
	my clickTwoLevel({"編集", "Edit"}, {"すべてを選択", "Select All"})
	delay 0.7
	tell application "System Events"
		repeat with k in containerIdx
			try
				set value of attribute "AXSelected" of row (contents of k) of ol to false
			end try
		end repeat
	end tell
	delay 0.5
	set sel to my selectedIndexes(ol)
	my logLine("方法1（すべてを選択→枠だけ解除）の結果: 選択中の行 = " & my joinInts(sel))
	if my sameSet(sel, targetIdx) then return "方法1: すべてを選択→枠だけ解除"
	
	-- 方法2: 対象の行を1行ずつ選択
	my clearSelection(ol)
	tell application "System Events"
		repeat with k in targetIdx
			try
				set value of attribute "AXSelected" of row (contents of k) of ol to true
			end try
		end repeat
	end tell
	delay 0.5
	set sel to my selectedIndexes(ol)
	my logLine("方法2（1行ずつ選択）の結果: 選択中の行 = " & my joinInts(sel))
	if my sameSet(sel, targetIdx) then return "方法2: 1行ずつ選択"
	
	-- 方法3: AXSelectedRows にまとめて設定
	my clearSelection(ol)
	tell application "System Events"
		set refs to {}
		repeat with k in targetIdx
			set end of refs to (row (contents of k) of ol)
		end repeat
		try
			set value of attribute "AXSelectedRows" of ol to refs
		end try
	end tell
	delay 0.5
	set sel to my selectedIndexes(ol)
	my logLine("方法3（まとめて設定）の結果: 選択中の行 = " & my joinInts(sel))
	if my sameSet(sel, targetIdx) then return "方法3: まとめて設定"
	return ""
end selectTargets

-- Chrome の読み込みシートを開き、ブックマークだけ読み込む
on doImport()
	set ok to my clickImportChromeByIndex()
	if not ok then error "「ファイル > ブラウザから読み込む > Google Chrome」が見つかりません"
	delay 2.5
	if my sheetCount() is 0 then error "読み込みシートが開きませんでした"
	tell application "System Events"
		tell process "Safari"
			set sh to sheet 1 of window 1
			set nCB to count of checkboxes of sh
			repeat with i from 1 to nCB
				set cb to checkbox i of sh
				set cbName to ""
				try
					set cbName to name of cb
				end try
				set cbVal to -1
				try
					set cbVal to value of cb
				end try
				if cbName is "ブックマーク" and cbVal is 0 then click cb
				if cbName is "履歴" then
					if (my importHistory) and cbVal is 0 then click cb
					if (not (my importHistory)) and cbVal is 1 then click cb
				end if
			end repeat
			set importBtn to missing value
			set nB to count of buttons of sh
			repeat with i from 1 to nB
				set b to button i of sh
				set bn to ""
				try
					set bn to name of b
				end try
				if bn is "読み込む" then set importBtn to b
			end repeat
			if importBtn is missing value then error "「読み込む」ボタンが見つかりません"
			set waited to 0
			repeat while waited < 15
				if (enabled of importBtn) is true then exit repeat
				delay 1
				set waited to waited + 1
			end repeat
			if (enabled of importBtn) is not true then error "「読み込む」ボタンが有効になりません（Chromeが終了していない可能性があります）"
			click importBtn
		end tell
	end tell
	-- 読み込み中は Safari に問い合わせない（v9 では読み込み中に Safari が固まったため）。
	-- 15秒待ってから、3秒おきにシートの有無とボタン名だけを確かめる
	delay 15
	set waited to 15
	repeat while waited < 180
		if my sheetCount() is 0 then exit repeat
		set btns to {}
		tell application "System Events"
			tell process "Safari"
				try
					set btns to name of every button of sheet 1 of window 1
				end try
			end tell
		end tell
		if btns does not contain "読み込む" then
			-- 完了メッセージ（例: 「Google Chromeから1,860個のブックマークが追加されました。」）
			set info to my sheetInfo()
			my logLine("読み込み後のシート: " & (item 1 of info) & " / ボタン=" & my joinList(btns, " | "))
			delay 2
			if my closeSheetWith({"OK", "完了", "閉じる", "Done", "Close"}) then
				my logLine("→ OK を押しました")
				delay 2
			else
				my logLine("→ 閉じるボタンが見つかりません")
			end if
		end if
		delay 3
		set waited to waited + 3
	end repeat
	if my sheetCount() > 0 then error "読み込みのシートが閉じません。画面の OK を手で押してください（押せない場合は教えてください）"
	my logLine("読み込みが終わりました（約" & waited & "秒）")
end doImport

-- いま開いているシートの {文字, ボタン名のリスト}
on sheetInfo()
	set txt to ""
	set btns to {}
	tell application "System Events"
		tell process "Safari"
			try
				set sh to sheet 1 of window 1
				try
					repeat with el in (entire contents of sh)
						try
							if role of el is "AXStaticText" then
								set v to value of el
								if v is not missing value then set txt to txt & (v as text) & " ／ "
							end if
						end try
					end repeat
				end try
				try
					set btns to name of every button of sh
				end try
			end try
		end tell
	end tell
	return {txt, btns}
end sheetInfo

-- シートのボタンのうち、names に最初に一致したものを押す
on closeSheetWith(names)
	tell application "System Events"
		tell process "Safari"
			try
				set sh to sheet 1 of window 1
				repeat with nm in names
					if exists button (contents of nm) of sh then
						click button (contents of nm) of sh
						return true
					end if
				end repeat
			end try
		end tell
	end tell
	return false
end closeSheetWith

on joinList(lst, sep)
	set s to ""
	repeat with x in lst
		try
			set v to contents of x
			if v is not missing value then
				if s is not "" then set s to s & sep
				set s to s & (v as text)
			end if
		end try
	end repeat
	return s
end joinList

-- 「編集」メニューの全項目と有効状態を記録する
on logEditMenu()
	tell application "System Events"
		tell process "Safari"
			try
				set mn to menu 1 of menu bar item "編集" of menu bar 1
				set s to ""
				repeat with i from 1 to count of menu items of mn
					set mi to menu item i of mn
					set nm to missing value
					try
						set nm to name of mi
					end try
					if nm is not missing value then
						set en to "?"
						try
							set en to (enabled of mi) as text
						end try
						set s to s & nm & "=" & en & " | "
					end if
				end repeat
				my logLine("編集メニュー: " & s)
			on error e
				my logLine("編集メニュー取得エラー: " & e)
			end try
		end tell
	end tell
end logEditMenu

on rowCount(ol)
	tell application "System Events" to return count of rows of ol
end rowCount

-- 行数が減るまで最大 secs 秒待つ。減ったら true
on waitRowsDecrease(ol, rowsBefore, secs)
	repeat (secs * 4) times
		if my rowCount(ol) < rowsBefore then return true
		delay 0.25
	end repeat
	return false
end waitRowsDecrease

-- 本物のキー入力（矢印キー）だけで行を選ぶ。
-- System Events のアクセシビリティ経由の選択や「click at」は Safari に選択として伝わっていなかったため（v6 のログ）。
on pressKey(kc)
	tell application "System Events"
		tell process "Safari"
			key code kc
		end tell
	end tell
	delay 0.35
end pressKey

-- 一番下の削除対象の行を、矢印キーで1行だけ選ぶ。選べた行番号を返す（だめなら 0）
on kbSelectLastTarget(ol, targetIdx, verbose)
	tell application "Safari" to activate
	delay 0.3
	my clickTwoLevel({"編集", "Edit"}, {"すべてを選択", "Select All"})
	delay 0.5
	my pressKey(125) -- ↓
	set sel to my selectedIndexes(ol)
	if verbose then my logLine("キー操作: すべてを選択→↓ の後の選択 = " & my joinInts(sel))
	if (count of sel) is not 1 then
		my pressKey(126) -- ↑
		set sel to my selectedIndexes(ol)
		if verbose then my logLine("キー操作: ↑ の後の選択 = " & my joinInts(sel))
	end if
	if (count of sel) is not 1 then return 0
	-- 一番下まで ↓ で移動
	set rc to my rowCount(ol)
	repeat rc times
		set prev to item 1 of sel
		my pressKey(125)
		set sel to my selectedIndexes(ol)
		if (count of sel) is not 1 then return 0
		if (item 1 of sel) is prev then exit repeat
	end repeat
	-- 削除対象の行に当たるまで ↑ で移動（枠の行は飛ばす）
	repeat rc times
		set cur to item 1 of sel
		if targetIdx contains cur then return cur
		if cur is 1 then return 0
		my pressKey(126)
		set sel to my selectedIndexes(ol)
		if (count of sel) is not 1 then return 0
	end repeat
	return 0
end kbSelectLastTarget

-- 削除対象を、下の行から1行ずつ「矢印キーで選ぶ → 削除」する
on deleteTargets(ol)
	repeat with n from 1 to 60
		my expandContainers(ol)
		set res to my collectTargets(ol)
		set tIdx to item 1 of res
		if (count of tIdx) is 0 then
			if (item 4 of res) > 0 then error "「お気に入り」などの枠に項目が残っています。読み込みせずに止めます。"
			my logLine("削除が終わりました")
			return
		end if
		set verbose to (n is 1)
		set idx to my kbSelectLastTarget(ol, tIdx, verbose)
		if idx is 0 then error "矢印キーで削除対象の行を選べませんでした。削除せずに止めます。"
		if not my sameSet(my selectedIndexes(ol), {idx}) then error "選択が対象の1行だけになっていません（行" & idx & "）"
		if verbose then my logEditMenu()
		set rowsBefore to my rowCount(ol)
		set how to "Deleteキー"
		my pressKey(51)
		set gone to my waitRowsDecrease(ol, rowsBefore, 3)
		if not gone then
			if not my sameSet(my selectedIndexes(ol), {idx}) then error "選択が変わったため止めました（行" & idx & "）"
			set how to "⌘＋Deleteキー"
			tell application "System Events"
				tell process "Safari"
					key code 51 using command down
				end tell
			end tell
			set gone to my waitRowsDecrease(ol, rowsBefore, 3)
		end if
		if not gone then
			if not my sameSet(my selectedIndexes(ol), {idx}) then error "選択が変わったため止めました（行" & idx & "）"
			set how to "編集 > 削除"
			my clickTwoLevel({"編集", "Edit"}, {"削除", "Delete"})
			set gone to my waitRowsDecrease(ol, rowsBefore, 3)
		end if
		if my sheetCount() > 0 then error "削除中に確認ダイアログが出たため、止めました"
		if not gone then
			if verbose then my logEditMenu()
			error "行" & idx & " を、Delete・⌘Delete・編集 > 削除 のどれでも消せませんでした。読み込みせずに止めます。"
		end if
		my logLine("削除: 行" & idx & "（" & how & "）")
	end repeat
	error "60回くり返しても削除が終わりませんでした"
end deleteTargets

-- 一番上の階層の行（読み込み先のフォルダ名の確認用）を記録する
on logTopLevel(ol)
	my logLine("読み込み後の一番上の階層:")
	try
		set rc to my rowCount(ol)
		repeat with i from 1 to rc
			set lvl to -1
			set t to ""
			tell application "System Events"
				set r to row i of ol
				try
					set lvl to (value of attribute "AXDisclosureLevel" of r) as integer
				end try
			end tell
			if lvl is 0 then my logLine("    行" & i & ": " & my shorten(my cellTexts(r)))
		end repeat
	on error e
		my logLine("（一覧の読み取りエラー: " & e & "）")
	end try
end logTopLevel

-- 「ブックマークを編集」画面を開く。すでに開いている（メニューが「ブックマークを非表示」になっている）ならそのまま使う
on openEditor()
	if my clickTwoLevel({"ブックマーク", "Bookmarks"}, {"ブックマークを編集", "Edit Bookmarks"}) then
		delay 3
		return
	end if
	set isOpen to false
	tell application "System Events"
		tell process "Safari"
			try
				set isOpen to exists menu item "ブックマークを非表示" of menu 1 of menu bar item "ブックマーク" of menu bar 1
			end try
		end tell
	end tell
	if isOpen then
		my logLine("「ブックマークを編集」画面はすでに開いていました")
		delay 1
		return
	end if
	error "「ブックマークを編集」が見つかりません"
end openEditor

-- 「ブックマークを編集」画面を閉じる（ブックマーク > ブックマークを非表示）
on closeEditor()
	set ok to my clickTwoLevel({"ブックマーク", "Bookmarks"}, {"ブックマークを非表示", "Hide Bookmarks"})
	if not ok then
		tell application "System Events"
			tell process "Safari"
				keystroke "b" using {option down, command down}
			end tell
		end tell
	end if
	delay 2
	tell application "System Events"
		tell process "Safari"
			try
				my logLine("編集画面を閉じた後のウィンドウ: " & (name of window 1))
			end try
		end tell
	end tell
end closeEditor

on runAll(doReal)
	tell application "Safari" to activate
	delay 1.5
	
	set chromeWasRunning to my chromeRunning()
	
	-- 前回の実行で残ったシートがあれば、内容を記録して閉じる
	if my sheetCount() > 0 then
		set info to my sheetInfo()
		my logLine("開始時に残っていたシート: 文字=" & (item 1 of info) & " / ボタン=" & my joinList(item 2 of info, " | "))
		if not my closeSheetWith({"OK", "完了", "閉じる", "Done", "Close", "キャンセル", "Cancel"}) then error "前回のシートが開いたままで、閉じられませんでした"
		delay 1.5
	end if
	
	my openEditor()
	delay 3
	set ol to my getOutline()
	my expandContainers(ol)
	
	set res to my collectTargets(ol)
	set selList to item 1 of res
	set totalRows to item 3 of res
	my logLine("展開後の行数: " & totalRows & " / 削除対象: " & (count of selList) & " 行")
	my logLine(item 2 of res)
	
	if (count of selList) > 0 then
		set selMethod to my selectTargets(ol, selList, item 5 of res)
		if selMethod is "" then error "削除対象だけを選択できませんでした。削除せずに止めます。"
		my logLine("選択に成功した方法: " & selMethod)
	else
		my logLine("削除対象はありません")
	end if
	
	if not doReal then
		if (count of selList) > 0 then
			set kIdx to my kbSelectLastTarget(ol, selList, true)
			my logLine("キー操作で選べた行（確認だけ・削除はしません）: " & kIdx)
			if kIdx > 0 then my logEditMenu()
		end if
		my logLine("確認だけのため、ここで終了しました（削除・Chromeの終了・読み込みはしていません）")
		return
	end if
	
	if (count of selList) > 0 then my deleteTargets(ol)
	
	-- 削除が終わってから Chrome を終了する（読み込みシートは Chrome が起動中だと押せないため）
	my quitChrome()
	tell application "Safari" to activate
	delay 1.5
	-- 読み込みの前に「ブックマークを編集」画面を閉じる（開いたままだと読み込み後に固まったため）
	my closeEditor()
	my doImport()
	-- 保存が落ち着くまで少し待ってから、編集画面を開き直して結果を確認する
	delay 5
	try
		my openEditor()
	end try
	try
		set ol to my getOutline()
		my logTopLevel(ol)
	on error e
		my logLine("（読み込み後の一覧を読めませんでした: " & e & "）")
	end try
	my closeEditor()
	my relaunchChrome()
end runAll

on run
	set outText to ""
	set msg to "Safari のブックマークを、Chrome の内容で置き換えます。" & return & return
	set msg to msg & "・Safari のブックマークはすべて削除されます（iCloud 経由で iPhone・iPad の Safari にも反映されます）" & return
	set msg to msg & "・Chrome を一度終了し、終わったら再起動します（保存していない作業は先に保存してください）" & return
	set msg to msg & "・履歴は読み込みません" & return & return
	set msg to msg & "実行前に「ファイル > ブラウズデータをファイルに書き出す…」でバックアップを取りましたか？" & return & return
	set msg to msg & "「確認だけ」を選ぶと、削除も Chrome の終了もせず、削除対象の一覧だけ確認できます。"
	set choice to ""
	try
		set choice to button returned of (display dialog msg buttons {"キャンセル", "確認だけ", "実行する"} default button "実行する" cancel button "キャンセル" with icon caution)
	on error number -128
		return
	end try
	set doReal to (choice is "実行する")
	
	try
		my logLine("スクリプト: v14")
		my runAll(doReal)
		set the clipboard to outText
		if doReal then
			display dialog "完了しました。Safari の「ブックマークを編集」画面で結果を確認してください。" & return & "経過ログをクリップボードにコピーしました。" buttons {"OK"} default button "OK"
		else
			display dialog "確認だけが終わりました。経過ログをクリップボードにコピーしました。チャットに貼り付けてください（⌘V）。" buttons {"OK"} default button "OK"
		end if
	on error e number n
		my logLine("エラー(" & n & "): " & e)
		if doReal then my relaunchChrome()
		set the clipboard to outText
		display dialog "途中で止まりました: " & e & return & return & "経過ログをクリップボードにコピーしました。チャットに貼り付けてください（⌘V）。" buttons {"OK"} default button "OK" with icon stop
	end try
end run
