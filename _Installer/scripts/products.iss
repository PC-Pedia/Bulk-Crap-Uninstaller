﻿#include "isxdl\isxdl.iss"

[CustomMessages]
DependenciesDir=MyProgramDependencies

depdownload_msg=The following applications are required before setup can continue:%n%n%1%nDownload and install now?  
pl.depdownload_msg=Do kontynuowania instalacji wymagane są następujące aplikacje:%n%n%1%nPobrać i zainstalować teraz?
fr.depdownload_msg=The following applications are required before setup can continue:%n%n%1%nDownload and install now?
de.depdownload_msg=The following applications are required before setup can continue:%n%n%1%nDownload and install now?

depdownload_memo_title=Download dependencies   
pl.depdownload_memo_title=Pobierz zależności
fr.depdownload_memo_title=Télécharger dépendances
de.depdownload_memo_title=Download Abhängigkeiten

depinstall_memo_title=Install dependencies 
pl.depinstall_memo_title=Zainstaluj zależności
fr.depinstall_memo_title=Installer les dépendances
de.depinstall_memo_title=Installieren Sie Abhängigkeiten

depinstall_title=Installing dependencies  
pl.depinstall_title=Instalacja zależności
fr.depinstall_title=Installation des dépendances
de.depinstall_title=Installation von Abhängigkeiten

depinstall_description=Please wait while Setup installs dependencies on your computer.   
pl.depinstall_description=Poczekaj aż instalator instaluje zależności na twoim komputerze.
fr.depinstall_description=Please wait while Setup installs dependencies on your computer.
de.depinstall_description=Please wait while Setup installs dependencies on your computer.

depinstall_status=Installing %1...   
pl.depinstall_status=Instalacja %1...
fr.depinstall_status=Installation %1...
de.depinstall_status=Installieren %1...

depinstall_missing=%1 must be installed before setup can continue. Please install %1 and run Setup again.  
pl.depinstall_missing=%1 musi być zainstalowany zanim instalacja może być kontynuowana. Zainstaluj %1 i ponownie uruchom program instalacyjny.
fr.depinstall_missing=%1 must be installed before setup can continue. Please install %1 and run Setup again.
de.depinstall_missing=%1 must be installed before setup can continue. Please install %1 and run Setup again.

depinstall_error=An error occured while installing the dependencies. Please restart the computer and run the setup again or install the following dependencies manually:%n     
pl.depinstall_error=Wystąpił błąd podczas instalowania zależności. Uruchom ponownie komputer i ponownie uruchom instalację lub ręcznie zainstaluj następujące zależności:%n
fr.depinstall_error=An error occured while installing the dependencies. Please restart the computer and run the setup again or install the following dependencies manually:%n
de.depinstall_error=An error occured while installing the dependencies. Please restart the computer and run the setup again or install the following dependencies manually:%n

isxdl_langfile=


[Files]
Source: "scripts\isxdl\english.ini"; Flags: dontcopy; Languages: en 
Source: "scripts\isxdl\polish.ini"; Flags: dontcopy; Languages: pl
Source: "scripts\isxdl\german2.ini"; Flags: dontcopy; Languages: de
Source: "scripts\isxdl\french2.ini"; Flags: dontcopy; Languages: fr

[Code]
type
	TProduct = record
		File: String;
		Title: String;
		Parameters: String;
		InstallClean : boolean;
		MustRebootAfter : boolean;
	end;

	InstallResult = (InstallSuccessful, InstallRebootRequired, InstallError);

var
	installMemo, downloadMemo, downloadMessage: string;
	products: array of TProduct;
	delayedReboot: boolean;
	DependencyPage: TOutputProgressWizardPage;


procedure AddProduct(FileName, Parameters, Title, Size, URL: string; InstallClean : boolean; MustRebootAfter : boolean);
var
	path: string;
	i: Integer;
begin
	installMemo := installMemo + '%1' + Title + #13;

	path := ExpandConstant('{src}{\}') + CustomMessage('DependenciesDir') + '\' + FileName;
	if not FileExists(path) then begin
		path := ExpandConstant('{tmp}{\}') + FileName;

		isxdl_AddFile(URL, path);

		downloadMemo := downloadMemo + '%1' + Title + #13;
		downloadMessage := downloadMessage + '	' + Title + ' (' + Size + ')' + #13;
	end;

	i := GetArrayLength(products);
	SetArrayLength(products, i + 1);
	products[i].File := path;
	products[i].Title := Title;
	products[i].Parameters := Parameters;
	products[i].InstallClean := InstallClean;
	products[i].MustRebootAfter := MustRebootAfter;
end;

function SmartExec(prod : TProduct; var ResultCode : Integer) : boolean;
begin
	if (LowerCase(Copy(prod.File,Length(prod.File)-2,3)) = 'exe') then begin
		Result := Exec(prod.File, prod.Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);
	end else begin
		Result := ShellExec('', prod.File, prod.Parameters, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode);
	end;
end;

function PendingReboot : boolean;
var	names: String;
begin
	if (RegQueryMultiStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager', 'PendingFileRenameOperations', names)) then begin
		Result := true;
	end else if ((RegQueryMultiStringValue(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Control\Session Manager', 'SetupExecute', names)) and (names <> ''))  then begin
		Result := true;
	end else begin
		Result := false;
	end;
end;

function InstallProducts: InstallResult;
var
	ResultCode, i, productCount, finishCount: Integer;
begin
	Result := InstallSuccessful;
	productCount := GetArrayLength(products);

	if productCount > 0 then begin
		DependencyPage := CreateOutputProgressPage(CustomMessage('depinstall_title'), CustomMessage('depinstall_description'));
		DependencyPage.Show;

		for i := 0 to productCount - 1 do begin
			if (products[i].InstallClean and (delayedReboot or PendingReboot())) then begin
				Result := InstallRebootRequired;
				break;
			end;

			DependencyPage.SetText(FmtMessage(CustomMessage('depinstall_status'), [products[i].Title]), '');
			DependencyPage.SetProgress(i, productCount);

			if SmartExec(products[i], ResultCode) then begin
				//setup executed; ResultCode contains the exit code
				//MsgBox(products[i].Title + ' install executed. Result Code: ' + IntToStr(ResultCode), mbInformation, MB_OK);
				if (products[i].MustRebootAfter) then begin
					//delay reboot after install if we installed the last dependency anyways
					if (i = productCount - 1) then begin
						delayedReboot := true;
					end else begin
						Result := InstallRebootRequired;
					end;
					break;
				end else if (ResultCode = 0) then begin
					finishCount := finishCount + 1;
				end else if (ResultCode = 3010) then begin
					//ResultCode 3010: A restart is required to complete the installation. This message indicates success.
					delayedReboot := true;
					finishCount := finishCount + 1;
				end else begin
					Result := InstallError;
					break;
				end;
			end else begin
				//MsgBox(products[i].Title + ' install failed. Result Code: ' + IntToStr(ResultCode), mbInformation, MB_OK);
				Result := InstallError;
				break;
			end;
		end;

		//only leave not installed products for error message
		for i := 0 to productCount - finishCount - 1 do begin
			products[i] := products[i+finishCount];
		end;
		SetArrayLength(products, productCount - finishCount);

		DependencyPage.Hide;
	end;
end;

function PrepareToInstall(var NeedsRestart: boolean): String;
var
	i: Integer;
	s: string;
begin
	delayedReboot := false;

	case InstallProducts() of
		InstallError: begin
			s := CustomMessage('depinstall_error');

			for i := 0 to GetArrayLength(products) - 1 do begin
				s := s + #13 + '	' + products[i].Title;
			end;

			Result := s;
			end;
		InstallRebootRequired: begin
			Result := products[0].Title;
			NeedsRestart := true;

			//write into the registry that the installer needs to be executed again after restart
			RegWriteStringValue(HKEY_CURRENT_USER, 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', 'InstallBootstrap', ExpandConstant('{srcexe}'));
			end;
	end;
end;

function NeedRestart : boolean;
begin
	if (delayedReboot) then
		Result := true;
end;

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
	s: string;
begin
	if downloadMemo <> '' then
		s := s + CustomMessage('depdownload_memo_title') + ':' + NewLine + FmtMessage(downloadMemo, [Space]) + NewLine;
	if installMemo <> '' then
		s := s + CustomMessage('depinstall_memo_title') + ':' + NewLine + FmtMessage(installMemo, [Space]) + NewLine;

	s := s + MemoDirInfo + NewLine + NewLine + MemoGroupInfo

	if MemoTasksInfo <> '' then
		s := s + NewLine + NewLine + MemoTasksInfo;

	Result := s
end;

function NextButtonClick(CurPageID: Integer): boolean;
begin
	Result := true;

	if CurPageID = wpReady then begin
		if downloadMemo <> '' then begin
			//change isxdl language only if it is not english because isxdl default language is already english
			if (ActiveLanguage() <> 'en') then begin
				ExtractTemporaryFile(CustomMessage('isxdl_langfile'));
				isxdl_SetOption('language', ExpandConstant('{tmp}{\}') + CustomMessage('isxdl_langfile'));
			end;
			//isxdl_SetOption('title', FmtMessage(SetupMessage(msgSetupWindowTitle), [CustomMessage('appname')]));

			if SuppressibleMsgBox(FmtMessage(CustomMessage('depdownload_msg'), [downloadMessage]), mbConfirmation, MB_YESNO, IDYES) = IDNO then
				Result := false
			else if isxdl_DownloadFiles(StrToInt(ExpandConstant('{wizardhwnd}'))) = 0 then
				Result := false;
		end;
	end;
end;

function IsX86: boolean;
begin
	Result := (ProcessorArchitecture = paX86) or (ProcessorArchitecture = paUnknown);
end;

function IsX64: boolean;
begin
	Result := Is64BitInstallMode and (ProcessorArchitecture = paX64);
end;

function IsIA64: boolean;
begin
	Result := Is64BitInstallMode and (ProcessorArchitecture = paIA64);
end;

function GetString(x86, x64, ia64: String): String;
begin
	if IsX64() and (x64 <> '') then begin
		Result := x64;
	end else if IsIA64() and (ia64 <> '') then begin
		Result := ia64;
	end else begin
		Result := x86;
	end;
end;

function GetArchitectureString(): String;
begin
	if IsX64() then begin
		Result := '_x64';
	end else if IsIA64() then begin
		Result := '_ia64';
	end else begin
		Result := '';
	end;
end;