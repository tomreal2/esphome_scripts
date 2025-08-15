create or replace PACKAGE BODY                "PKG_MODEL_TOOLS" AS
 
error_message varchar2(4096);

procedure err_handler(func_name varchar2, err_message varchar2) is
begin
	if error_message is null then
		error_message:=func_name||' -> '||err_message;
	else
		error_message:=error_message||' | '||func_name||' -> '||err_message;
	end if;
end;

function f_get_json_value(in_key varchar2, in_val varchar2) return json_value as
	lc_jObj json;
begin
	lc_jObj := json();
	lc_jObj.put(in_key,in_val);
	return lc_jObj.to_json_value();

	exception when others then
		--htp.p('error in f_get_json_value');
		return null;
end;

function f_last_quote_sing_or_doub(in_clob clob) return varchar2 as
	--last quote sing or doub determines if the final quote that appears in the clob param is a single or double quote

	--ASSUMPTIONS
	--The clob passed in contains at least one single or double quote

	--ACTIONS
	--ACTION 1: find the final positions of both single quote and double quote
	--ACTION 2: based on the largest position of single vs double quote, return a single or double quote

	lc_funcName varchar2(256):='f_last_quote_sing_or_doub';
	lc_nSinglePos pls_integer;
	lc_nDoublePos pls_integer;
begin

	--find position of last single and double quotes
	lc_nSinglePos := instr(in_clob,'''',-1);
	lc_nDoublePos := instr(in_clob,'"',-1);

	--return the quote that appears last
	if lc_nSinglePos > lc_nDoublePos then
		return '''';
	else
		return '"';
	end if;

	exception when others then
		err_handler(lc_funcName,sqlerrm);
		return null;
end;

function f_transform_chunk(in_vOldName varchar2, in_vNewName varchar2, in_clChunk clob) return clob as
	--transform chunk modifies every reference to the original filename - changing it to the id based name with no prefixed directory

	--ASSUMPTIONS
	--If the old name appears in the chunk, it will be wrapped in single or double quotes

	--ACTIONS
	--ACTION 1: Loop on each instance of the original filename
	--ACTION 2: Split into 2 clobs at the point the filename appears
	--ACTION 3: determine single vs double quote wrappers by passing first clob and filename position to f_last_quote_sing_or_doub()
	--ACTION 4: find position of the quote wrappers in each of the 2 clobs
	--ACTION 5: concatenate two clobs (trimming each to the wrapping quote) with id based filename in the middle
	--ACTION 6: after looping on every other file, return the newly modified clob chunk


	lc_funcName varchar2(256):='f_transform_chunk';
	lc_clChunk clob;

	lc_nPos pls_integer;

	lc_clPreClob clob;
	lc_clSufClob clob;

	lc_vQuote varchar2(1);
	lc_nStartPos pls_integer;
	lc_nEndPos pls_integer;

begin
	lc_clChunk := in_clChunk;

	lc_nPos := instr(lc_clChunk, in_vOldName); --'Layer_CVN_Utility_Boom-1-FACES_normalBinary.bin+4');
	dbms_output.put_line('replace name found = '||lc_nPos);

	--ITERATE THIS CHUNK --REPLACE OLD NAMES WITH NEW NAMES - CHUNK BY CHUNK
	while lc_nPos > 0 loop
		dbms_output.put_line('pos of replacement str = '||lc_nPos);

		--SPLIT CLOB AT REPLACEMENT NAME
		lc_clPreClob := substr(lc_clChunk,0,lc_nPos-1);
		lc_clSufClob := substr(lc_clChunk,lc_nPos);

		--determine single vs double lc_vQuote wrapper
		lc_vQuote := f_last_quote_sing_or_doub(lc_clPreClob);
		if lc_vQuote is null then
			return null;
		end if;

		--get positions of quote
		lc_nStartPos := instr(lc_clPreClob,lc_vQuote,-1);
		lc_nEndPos   := instr(lc_clSufClob,lc_vQuote,1);

		--CONCATENATE SPLIT CLOBS WITH NEW NAME (this will work bc chunk is 32k max)
		lc_clChunk := substr(lc_clPreClob,0,lc_nStartPos) || in_vNewName || substr(lc_clSufClob,lc_nEndPos);

		lc_nPos := instr(lc_clChunk, in_vOldName);
		dbms_output.put_line('replace name found = '||lc_nPos);
  end loop;

  return lc_clChunk;
	exception when others then
		err_handler(lc_funcName,sqlerrm);
		return null;
end;



function f_change_all_filenames(in_nModeluploadid varchar, in_nModelid number, in_clChunk clob) return clob as
-- change all filenames acts on one 'chunked' CLOB at a time
-- It iterates all of the OTHER files with the same modelid
-- For each chunk -it passes: original file_name, the new id filename, and blob to f_transform_chunk()
-- it retuns the new transformed chunk

--ASSUMPTIONS
--1. if other files w/same modelid are found, they have attributes: file_name and file_ext

--ACTIONS
--ACTION 1: Loop on curser - all SPD_T_MODEL_UPLOADS with same modelid but IGNORE the current file
--ACTION 2: pass the original filename, the new id based filename, and the clob chunk to f_transform_chunk()
--ACTION 3: return the modified chunk

	lc_funcName varchar2(256):='f_change_all_filenames';
	lc_clChunk clob := in_clChunk;

	CURSOR lc_cuFiles
		IS
		SELECT modeluploadid, file_name, file_ext, file_blob FROM SPIDERS3D.SPD_T_MODEL_UPLOADS WHERE MODELID = in_nModelid AND modeluploadid <> in_nModeluploadid;
begin

	FOR rec IN lc_cuFiles LOOP
			lc_clChunk := f_transform_chunk(rec.file_name, rec.modeluploadid || rec.file_ext, lc_clChunk);
			if lc_clChunk is null then
				return null;
			end if;
	END LOOP;

	return lc_clChunk;
	exception when others then
		err_handler(lc_funcName,sqlerrm);
		return null;
end;



function f_transoform_file(in_nModeluploadid varchar, in_nModelid number, in_bBlob blob) return blob as
-- transform file alters references to other files by 
-- removing any prefixed subfolders (floattening) 
-- and changing the referenced filename to the new id based name

--ASSUMPTIONS
--1. in_bBlob IS A VALID TEXT FILE

--ACTIONS
--Action 1: Iterate the clob file chunk by chunk (each chunk is 31k)
--Action 2: Modify each chunk using f_change_all_filenames()
--Action 3: Append each modified chunk into a new CLOB
--Action 4: Convert the new CLOB to a BLOB and return

	lc_funcName varchar2(256):='f_transoform_file';
	lc_clOriginalClob clob;
	lc_clNewClob clob;
	lc_clClobChunk clob;

	lc_nLobLength pls_integer;
	lc_nOffset number;
	lc_nBuffSize number := 31000;
	lc_vBuffer varchar2(31000);

begin
	--modify file, return a CLOB
	lc_clOriginalClob:= blob_to_clob(in_bBlob);

		---CHUNK THE CLOB
	FOR i IN 0..1000 LOOP
		lc_nOffset := i * lc_nBuffSize + 1;

		--Load current chunk into buffer
		lc_vBuffer := DBMS_LOB.SUBSTR(lc_clOriginalClob, lc_nBuffSize, lc_nOffset);

		--convert buffer chunk into clob
		lc_clClobChunk := TO_CLOB(lc_vBuffer);
		EXIT WHEN lc_clClobChunk IS NULL OR lc_nLobLength < lc_nOffset;

		--CHANGE lc_clClobChunk
		lc_clClobChunk := f_change_all_filenames(in_nModeluploadid,in_nModelid,lc_clClobChunk);
		if lc_clClobChunk is null then
			return null;
		end if;

		--APPEND lc_clClobChunk TO lc_clNewClob		
		if lc_clNewClob is null then 
			lc_clNewClob := lc_clClobChunk;
		else
			DBMS_LOB.APPEND(lc_clNewClob, lc_clClobChunk);
		end if;
	END LOOP;

	return clob2blob(lc_clNewClob);
	exception when others then
		err_handler(lc_funcName,sqlerrm);
		return null;
end;


function f_confirm_upload(in_nModelid number, lc_jlDML in out json_list) return BOOLEAN as
	lc_funcName varchar2(256):='f_confirm_upload';

	lc_nPrimaryFileCount number;
	lc_nThumnailFileCount number;
begin
	  select count(p.modeluploadid) into lc_nPrimaryFileCount
		from spiders3d.spd_t_model_uploads p
		where p.file_ext is not null and p.modelid = in_nModelid and lower(p.file_role) = 'primary' and rownum = 1;

		if lc_nPrimaryFileCount < 1 then
			--lc_jlDML.append('{''userError1'':''You must upload a primary X3D file.''}');
			lc_jlDML.append(f_get_json_value('userError','You must upload a primary X3D file.'));
		end if;

		select count(p.modeluploadid) into lc_nThumnailFileCount
		from spiders3d.spd_t_model_uploads p
		where p.file_ext is not null and p.modelid = in_nModelid and lower(p.file_role) = 'thumbnail' and rownum = 1;

		if lc_nThumnailFileCount < 1 then
			--lc_jlDML.append('{''userError2'':''You must upload a valid thumbnail image.''}');
			lc_jlDML.append(f_get_json_value('userError','You must upload a valid thumbnail image.'));
		end if;

		return lc_nThumnailFileCount = 1 AND lc_nPrimaryFileCount = 1;
end;

function f_process_files(in_cJson clob) return json as
--process files accepts a modelid so it can iterate newly uploaded model library files.
--each file must be:
-- renamed to an id with the original file extension
-- saved to directory: .../htdocs/SPIDERS3D/UPLOADS/X3D/
-- if file is an x3d file then all references to other files must be altered:
--	remove prefixed subfolders (all referenced files will be in same directory)
--  change the referenced filename to be the new id name

--ASSUMPTIONS:
--1. All uploaded files have a valid blob and file_ext (varchar2) attribute

--ACTIONS:
-- ACTION 1: Confirm that both a primary x3d and a thumbnail file have been uploaded
-- Action 2: Loop on cursor - all files with given modelid
-- Action 3: Determine if current file in iteration is an x3d file
-- Action 4: Transform file references if x3d file via f_transoform_file()
-- Action 5: Save file with id based filename to .../htdocs/SPIDERS3D/UPLOADS/X3D/
-- Action 6: Return new filename if primary x3d file

	lc_funcName varchar2(256):='f_process_files';

	in_nModelid number;

	cust_err_no_blob EXCEPTION;
	cust_err_no_transofrmed_blob EXCEPTION;
	lc_clNewblob blob;

	lc_jJson json;
	lc_jlDML json_list;
	lc_jReturn json;

	lc_bUploadConfirmed boolean := false;

	--lc_jObj json;

	--CURSOR lc_cuFiles
	--IS
	--SELECT modeluploadid, file_ext, file_blob FROM SPIDERS3D.SPD_T_MODEL_UPLOADS WHERE MODELID = in_nModelid;
begin

  --INITIALIZE RETURN OBJECTS
  lc_jlDML := json_list();
  lc_jReturn := json();

  begin
		--Action 1: Get modelid value and store it as in_nModelid
		--lc_jlDML := json_list();

		lc_jJson := json(in_cJson);
		in_nModelid := getCorrespondingJsonColumnVal(lc_jJson, 'MODELID');
		lc_jReturn := json();

		--lc_jlDML.append('{''good1_1'':''success''}');
		lc_jlDML.append(f_get_json_value('status','success1_1'));

	exception when others then
		--lc_jlDML.append('{''err1_1'':''' || sqlerrm || '''}');
		lc_jlDML.append(f_get_json_value('error1_1',sqlerrm));
	end;

  if in_nModelid is not null then
  	--CONFIRM THAT A PRIMARY x3d AND A THUMBNAIL HAVE BEEN UPLOADED
  	lc_bUploadConfirmed := f_confirm_upload(in_nModelid, lc_jlDML);
  end if;

  if lc_bUploadConfirmed then

		FOR rec IN (SELECT modeluploadid, file_ext, file_blob, file_role FROM SPIDERS3D.SPD_T_MODEL_UPLOADS WHERE MODELID = in_nModelid) --lc_cuFiles
		LOOP

			-- TRANSFORM THE FILE - IF X3D
			if LOWER(rec.file_ext) = '.x3d' then
				lc_clNewblob := f_transoform_file(rec.modeluploadid, in_nModelid, rec.file_blob);
				--VERIFY RESULTS
				if lc_clNewblob is null then
					RAISE cust_err_no_transofrmed_blob;
				end if;
			else
				lc_clNewblob := rec.file_blob;
				--VERIFY RESULTS
				if lc_clNewblob is null then
					RAISE cust_err_no_blob;
				end if;
			end if;	

			--WRITE FILE TO .../UPLOADS/X3D
			if lc_clNewblob is not null then
				zip_util_pkg.save_zip(lc_clNewblob,'SPD_UPLOADS_X3D',rec.modeluploadid || LOWER(rec.file_ext));
				if LOWER(rec.file_role) = 'primary' then
					--RETURN NEW FILENAME IF PRIMARY X3D FILE
					--lc_jObj := json();
					--lc_jObj.put('primaryFileName',rec.modeluploadid || LOWER(rec.file_ext) );
					--lc_jlDML.append('{''primaryFileName'':''' || rec.modeluploadid || LOWER(rec.file_ext) || '''}');
					lc_jlDML.append(f_get_json_value('primaryFileName',rec.modeluploadid || LOWER(rec.file_ext)));
					--lc_jlDML.append(lc_jObj);
				end if;
			end if;
		END LOOP;
	end if;


	--return 'success';
	commit;
	lc_jReturn.put('results',lc_jlDML);
	return lc_jReturn;


	exception 
  when cust_err_no_blob then
		if sqlerrm is null then
      err_handler(lc_funcName,sqlerrm);
		else
			err_handler(lc_funcName,'CUSTOM ERROR: missing blob from SPD_T_MODEL_UPLOADS');
		end if;
		--lc_jlDML.append('{''err1_2'':''' || error_message || '''}');
		lc_jlDML.append(f_get_json_value('error1_2',error_message));
    lc_jReturn.put('results',lc_jlDML);
		return lc_jReturn;
	when cust_err_no_transofrmed_blob then
		if sqlerrm is not null then
			err_handler(lc_funcName,sqlerrm);
		else
			err_handler(lc_funcName,'CUSTOM ERROR: f_transoform_file returned null');
		end if;
		--lc_jlDML.append('{''err1_3'':''' || error_message || '''}');
		lc_jlDML.append(f_get_json_value('error1_3',error_message));
    lc_jReturn.put('results',lc_jlDML);
		return lc_jReturn;
	when others then
		err_handler(lc_funcName,sqlerrm);
		--lc_jlDML.append('{''err1_4'':''' || error_message || '''}');
		lc_jlDML.append(f_get_json_value('error1_4',error_message));
		lc_jReturn.put('results',lc_jlDML);
		return lc_jReturn;
end;

function f_add_model(in_cJson clob) return json as
--add model accepts a .modeluploadid so it can add the model to model library.
--a new record must be inserted into the model table:
-- Source data comes from: SPD_T_MODEL_UPLOADS
-- SPD_T_MODELS.SRC = new file where file_role = primary
-- SPD_T_MODELS.THUMBNAILSRC = new file where file_role = thumbnail 
-- INSERT must include the primary key (MODELID) found in SPD_T_MODEL_UPLOADS


--ASSUMPTIONS:
--1. All uploaded files have a valid blob and file_ext (varchar2) attribute

--ACTIONS:
-- Action 1: Select SPD_T_MODEL_UPLOADS record with modeluploadid
-- Action 2: Determine if current file in iteration is an x3d file
-- Action 3: Transform file references if x3d file via f_transoform_file()
-- Action 4: Save file with id based filename to .../htdocs/SPIDERS3D/UPLOADS/X3D/
-- Action 5: Return new filename if primary x3d file
	lc_funcName varchar2(256):='f_add_model';

	in_nModelid number;
	in_vModelName varchar2(1024);
	in_vDescription varchar2(1024);

	lc_bUploadConfirmed boolean := false;
	lc_nModelCount number;

	lc_vSrc varchar2(1024);
	lc_vThumbnailSrc varchar2(1024);

	lc_jJson json;
	lc_jlDML json_list;
	lc_jReturn json;

	lc_vUrlPrefix varchar2(256) := '/SPIDERS3D/UPLOADS/X3D/';
begin
  --INITIALIZE RETURN OBJECTS
  lc_jlDML := json_list();
  lc_jReturn := json();

  begin
		--Action 1: Get modelid value and store it as in_nModelid
		lc_jJson := json(in_cJson);
		in_nModelid := getCorrespondingJsonColumnVal(lc_jJson, 'MODELID');
		--lc_jlDML.append('{''good1_1'':''success''}');
		lc_jlDML.append(f_get_json_value('status','success1_1'));
	exception when others then
		--lc_jlDML.append('{''err1_1'':''' || sqlerrm || '''}');
		lc_jlDML.append(f_get_json_value('error1_1',sqlerrm));
	end;


  begin
		--Action 1: Get modelid value and store it as in_nModelid
		lc_jJson := json(in_cJson);
		in_vModelName := getCorrespondingJsonColumnVal(lc_jJson, 'MODELNAME');
		--lc_jlDML.append('{''good1_2'':''success''}');
		lc_jlDML.append(f_get_json_value('status','success1_2'));
	exception when others then
		--lc_jlDML.append('{''err1.2'':''' || sqlerrm || '''}');
		lc_jlDML.append(f_get_json_value('error1_2',sqlerrm));
	end;

	begin
		--Action 1: Get modelid value and store it as in_nModelid
		lc_jJson := json(in_cJson);
		in_vDescription := getCorrespondingJsonColumnVal(lc_jJson, 'DESCRIPTION');
		--lc_jlDML.append('{''good1_3'':''success''}');
		lc_jlDML.append(f_get_json_value('status','success1_3'));
	exception when others then
		--lc_jlDML.append('{''err1_3'':''' || sqlerrm || '''}');
		lc_jlDML.append(f_get_json_value('error1_3',sqlerrm));
	end;



  if in_vModelName is not null and in_vDescription is not null and in_nModelid is not null then
  	--CONFIRM THAT A PRIMARY x3d AND A THUMBNAIL HAVE BEEN UPLOADED
  	lc_bUploadConfirmed := f_confirm_upload(in_nModelid, lc_jlDML);
  end if;

  --INSERT INTO MODEL
  if lc_bUploadConfirmed and in_vModelName is not null and in_vDescription is not null and in_nModelid is not null then

  	--THIS WILL WORK BC WE HAVE CONFIRMED VALID DATA IN FUNCTION: f_confirm_upload
  	select modeluploadid||file_ext into lc_vSrc from spiders3d.spd_t_model_uploads where file_ext is not null and modelid = in_nModelid and lower(file_role) = 'primary' and rownum = 1;
  	select modeluploadid||file_ext into lc_vThumbnailSrc from spiders3d.spd_t_model_uploads where file_ext is not null and modelid = in_nModelid and lower(file_role) = 'thumbnail' and rownum = 1;

  	--CONFIRM THAT THIS MODELID DOES NOT EXIST IN SPD_T_MODELS TABLE
  	select count(modelid) into lc_nModelCount from spiders3d.spd_t_models where modelid = in_nModelid;
  	if lc_nModelCount = 0 then
  		insert into spiders3d.spd_t_models (modelid, modelname, description, src, thumbnailsrc) values (in_nModelid,in_vModelName,in_vDescription,lc_vUrlPrefix||lc_vSrc,lc_vUrlPrefix||lc_vThumbnailSrc);
  	else
  		--lc_jlDML.append('{''userError'':''Current model has already been added to the model library.''}');
  		lc_jlDML.append(f_get_json_value('userError','Current model has already been added to the model library.'));
  	end if;

  end if;

  commit;
	lc_jReturn.put('results',lc_jlDML);
	return lc_jReturn;

	exception when others then
		err_handler(lc_funcName,sqlerrm);
		--lc_jlDML.append('{''err1_4'':''' || error_message || '''}');
		lc_jlDML.append(f_get_json_value('error1_4',error_message));
		lc_jReturn.put('results',lc_jlDML);
		return lc_jReturn;
end;


function f_cancel_processed_files(in_cJson clob) return json as
--cancel processed files accepts a modelid so it can remove all uploaded files.

--ASSUMPTIONS:
--1. The modelid is a valid number and an id in SPD_T_MODEL_UPLOADS

--ACTIONS:
-- ACTION 1: Retrieve the modelid parameter
-- Action 2: Delete all records from SPD_T_MODEL_UPLOADS
	lc_funcName varchar2(256):='f_cancel_processed_files';

	in_nModelid number;

	lc_jJson json;
	lc_jlDML json_list;
	lc_jReturn json;


begin

  --INITIALIZE RETURN OBJECTS
  lc_jlDML := json_list();
  lc_jReturn := json();

  begin
		--Action 1: Get modelid value and store it as in_nModelid
		lc_jJson := json(in_cJson);
		in_nModelid := getCorrespondingJsonColumnVal(lc_jJson, 'MODELID');
		lc_jReturn := json();

		--lc_jlDML.append('{''good1_1'':''success''}');
		lc_jlDML.append(f_get_json_value('status','success1_1'));
	exception when others then
		--lc_jlDML.append('{''err1_1'':''' || sqlerrm || '''}');
		lc_jlDML.append(f_get_json_value('error1_1',sqlerrm));
	end;

	DELETE FROM SPIDERS3D.SPD_T_MODEL_UPLOADS WHERE MODELID = in_nModelid;
	--lc_jlDML.append('{''good1_2'':''success''}');
	lc_jlDML.append(f_get_json_value('status','success1_2'));

	commit;
	lc_jReturn.put('results',lc_jlDML);
	return lc_jReturn;

	exception when others then
		err_handler(lc_funcName,sqlerrm);
		--lc_jlDML.append('{''err1.2'':''' || error_message || '''}');
		lc_jlDML.append(f_get_json_value('error1_2',error_message));
		lc_jReturn.put('results',lc_jlDML);
		return lc_jReturn;
end;

END PKG_MODEL_TOOLS;

