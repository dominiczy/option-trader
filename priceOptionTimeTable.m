classdef priceOptionTimeTable < stock
    % 3d table with option info, price info for various time stamps
    % 'timestamp': datenum of time/date for when data was fetched
    % 'page': option and price info for specific time stamp
    % 'optSlice': a specific option table var accross range of time stamps
    % 'priceSlice': price info accross range of time stamps
    % table3d is a struct with following properties:
    %   -under: timeTable with following varNames:
    %       timestamp | last | open | high | low | prevClose | volume |
    %       dividendAmount (also add for future dates) | earnings (boolean, also for
    %       future dates)
    %   -option: tall timetable
    %       timestamp | callLast | callChg | callBid | callAsk | callVol | callOpenInt |
    %       | expDate | strike | 
    %           putLast | putChg | putBid | putAsk | putVol | putOpenInt
    
    properties
        option3dDs; % data store for option3d
        option3d; % tall time table with option info for various timestamps
        histOption2d; % fast access for used timestamps
        option2d;% latest page of option3d. 
        
        price2dDs;
        price2d; % table with price info for various timestamps      
    end
    
    methods
        function obj = priceOptionTimeTable (varargin)
            fprintf('Constructing priceOptionTimeTable.\n')
            obj = obj@stock(varargin{:});
            if isempty(obj.price2d)
                obj.loadFromFiles(); 
            end
        end
        
        % loads option3d and price2d from existing files
        function loadFromFiles (obj)
            % fprintf('Executing %s: loadFromFiles $s.\n', class(obj), obj.symbol)            
            try
                obj.price2dDs = tabularTextDatastore([namedConst.histFolder obj.symbol '_*_' namedConst.pricePageEnd namedConst.pageExtension]);
            catch ME
				if namedConst.warnings
					warning(['No price data loaded for ' obj.symbol '. Error: ' ME.message])
				end
            end
            try
                obj.option3dDs = tabularTextDatastore([namedConst.histFolder obj.symbol '_*_' namedConst.optionPageEnd namedConst.pageExtension]);
                obj.histOption2d = containers.Map();  
            catch ME
                if namedConst.warnings
                    warning(['No option data loaded for ' obj.symbol '. Error: ' ME.message])
                end
            end 
        end
       
        function setOption3dFromDs (obj)
            fprintf('Executing %s: setOption3dFromDs for %s.\n', class(obj), obj.symbol)  
            % merge price info with option3d
            price2dNonDailyDs = tabularTextDatastore(strrep(obj.option3dDs.Files, '_option', '_price'));
            price2dNonDailyDs.SelectedVariableNames = {'timestamp','last','prevClose', 'volume'};
            price2dNonDaily = table2timetable(readall(price2dNonDailyDs));
            price2dNonDaily = obj.getPrice2dOptionAdd(price2dNonDaily);
            obj.option3d = table2timetable(tall(obj.option3dDs));
            obj.option3d = join(obj.option3d, price2dNonDaily);
        end
        
        function loadSpreadsFromFiles (obj)
            fprintf('Executing %s: loadSpreadsFromFiles for %s.\n', class(obj), obj.symbol)
            try
                spreads = tabularTextDatastore([namedConst.histFolder obj.symbol '_*_' namedConst.spreadEnd namedConst.pageExtension]);
                spreadTable = readall(spreads);
                uniqueExpDates = unique(spreadTable.expDate);
                % for every expDate get only identical strikes with latest
                % timestamp, and make sure they're unique
                for i = 1:numel(uniqueExpDates)
                    dateTable = spreadTable(spreadTable.expDate == uniqueExpDates(i), :);
                    uniqueStrikes = unique(dateTable.strike);
                    for j = 1:numel(uniqueStrikes)
                        strikeTable = dateTable(dateTable.strike == uniqueStrikes(j), :);
                        if size(strikeTable,1) > 1
                            lastTimestamp = max(strikeTable.timestamp);
                            % throw away everything that does not have
                            % latest timestamp
                            spreadTable(spreadTable.expDate == uniqueExpDates(i) & spreadTable.strike == uniqueStrikes(j) & spreadTable.timestamp ~= lastTimestamp, :) = [];
                        end
                    end
                end
                spreadTable.timestamp = [];
                option2d = outerjoin(obj.getOption2d(), spreadTable, 'Keys', obj.basics, 'Type','left', 'MergeKeys',true);
                option2d.callQuantity(isnan(option2d.callQuantity)) = 0;
                option2d.putQuantity(isnan(option2d.putQuantity)) = 0;
                obj.option2d = option2d;
            catch ME
                obj.addSpreadVars();
                if namedConst.downloadVerbose
                    warning(['No spread data loaded for ' obj.symbol '. Error: ' ME.message])
                end
            end   
        end
        
        % GETTERS AND SETTERS
        
        % PRICE1D
        
         % get a field from price1d for a specific time (or latest if empty)
        function [price1dVar, price1d] = getPrice1dVar (obj, priceVar, varargin)
            price1d = obj.getPrice1d (varargin{:});
            price1dVar = obj.getVarIfExist(priceVar, price1d);
        end
        
        % this can be called from calc function
        function value = setPrice1dVar (obj, priceVar, value, varargin)
            % add priceVar to price2d if not exists
            if ~ismember (priceVar, obj.price2d.Properties.VariableNames)
                if ischar(value)
                    obj.setPrice2dVar (priceVar, cell (size(obj.price2d,1),1), varargin{:}); % set cell
                else
                    obj.setPrice2dVar (priceVar, zeros (size(obj.price2d,1),1), varargin{:}); % set zeros
                end
            end
             % always set in obj.price2d line
            obj.price2d{obj.getTimestamp(varargin{:}),priceVar} = value;
        end
        
        % return price 1d
        function price1d = getPrice1d (obj, varargin)
            price1d = obj.price2d(obj.getTimestamp(varargin{:}),:);
        end
        
        % no price1d can be set for any timestamp other than last
        function value = setPrice1d (obj, value)
			% obj.price1d = value;          
			price1dMissing = setdiff(obj.price2d.Properties.VariableNames, value.Properties.VariableNames);
			value = [value array2table(nan(1, numel(price1dMissing)), 'VariableNames', price1dMissing)];
			obj.setPrice2d (vertcat(obj.getPrice2d(), value)); 
        end
        
        % PRICE2D
        
         % get a field from price1d for a specific time (or latest if empty)
        function [price2dVar, price2d] = getPrice2dVar (obj, priceVar, varargin)
            price2d = obj.getPrice2d (varargin{:});
            price2dVar = obj.getVarIfExist(priceVar, price2d);
        end
        
        % this can be called from calc function
		% no price2dVar can be set for any time other than last
        function value = setPrice2dVar (obj, priceVar, value)
			% set in obj.price2d and obj.price1d
			obj.price2d.(priceVar) = value;
        end
        
        % return price 2d
        function price2d = getPrice2d (obj, varargin)
            if isempty(obj.price2d)
                obj.setPrice2dFromDs();
            end
            if numel(varargin) < 1 || isempty(varargin{1}) % avoid recursion at init
                price2d = obj.price2d;
            else
                price2d = obj.price2d(obj.price2d.Properties.RowTimes <= obj.getTimestamp(varargin{:}),:);
            end
        end
        
        function setPrice2dFromDs (obj)
            fprintf('Executing %s: setPrice2dFromDs for %s.\n', class(obj), obj.symbol)      
            obj.setPrice2d (table2timetable(readall(obj.price2dDs)));
        end
        
        % set whole price2d
        % no price2d can be set for any time other than last
        function value = setPrice2d (obj, value)
            value = sortrows(value);   
			obj.price2d = value;   
        end
        
        % OPTION2D
        
         % get a field from option2d for a specific time (or latest if empty)
        function [option2dVar, option2d] = getOption2dVar (obj, optionVar, varargin)
            option2d = obj.getOption2d (varargin{:});
            option2dVar = obj.getVarIfExist(optionVar, option2d);
        end
        
         % get a field from option2d for a specific time (or latest if empty)
        function [option2dVar, option2d] = getOption2dVarFor (obj, optionVar, expDate, strike, spreadComment, varargin)
            [option2dVar, option2d] = obj.getOption2dVar (optionVar, varargin{:});
            if ~isempty(option2dVar)
                rows = ones (size(option2d, 1), 1);
                 % filter expDate
                if ~isempty(expDate) 
                    rows = rows & (option2d.expDate == expDate);
                end
                % filter strike if exists
                if exist('strike', 'var') && ~isempty(strike) 
                    rows = rows & (option2d.strike == strike);
                end
                % filter comment if exists
                if exist('spreadComment', 'var') && ~isempty(spreadComment) 
                    rows = rows & strcmpi(option2d.spreadComment, spreadComment);
                end
                option2dVar = option2dVar(rows);
                option2d = option2d(rows, :);
            end
        end
        
        % this can be called from calc function
        function value = setOption2dVar (obj, optionVar, value, varargin)
			if obj.getTimestamp(varargin{:}) == obj.getTimestamp()
				obj.option2d.(optionVar) = value;
            else
                histOption2d = obj.getOption2d(varargin{:});
                histOption2d.(optionVar) = value;
                obj.histOption2d(datestr(obj.getNonDailyTimestamp(varargin{:}))) = histOption2d;
			end
        end
        
        % return option 2d
        function option2d = getOption2d (obj, varargin)
            if obj.getTimestamp(varargin{:}) == obj.getTimestamp()
                if isempty(obj.option2d) % happens on init, in this case load from option3d
                    obj.option2d = obj.loadFromOption3d (obj.getNonDailyTimestamp());
                end
				option2d = obj.option2d;
            else
                timestamp = obj.getNonDailyTimestamp(varargin{:});
                obj.setHistOption2d (timestamp);
                option2d = obj.histOption2d (datestr(timestamp));
            end
            % remove expiry dates equal to or smaller than settle date
            option2d = option2d(option2d.expDate > obj.getSettleDate (varargin{:}), :);
        end
        
        function setHistOption2d (obj, timestamp)
            % check if accessed before
            if ~isKey(obj.histOption2d, datestr(timestamp))
                obj.histOption2d(datestr(timestamp)) =  obj.loadFromOption3d (timestamp);
            end
        end  
        
        function option3d = getOption3d (obj)
            if ~istall(obj.option3d)
               obj.setOption3dFromDs(); 
            end
            option3d = obj.option3d;
        end
        
        function option2d = loadFromOption3d (obj, timestamp)
            option3d = obj.getOption3d();
            option2d = option3d(timestamp,:);
            option2d = gather(option2d);
        end
        
        % can only be set for timestamp last
        function value = setOption2d (obj, value)
            loadSpreads = false;
            % if there are spreads to be preserved
            if ~isempty(obj.option2d) && ismember ('putQuantity', obj.option2d.Properties.VariableNames) && ~isempty(find(obj.getOption2dVar ('putQuantity'), 1))  
                spreadTable = obj.getSpreads ();
                loadSpreads = true;
            end            
			% new data, set in obj.option2d
			obj.option2d = value(value.expDate > obj.getSettleDate (), :);    
            if loadSpreads
                % restore spreads
                obj.setSpreads (spreadTable);
            end
        end
        
        % value (scalar) is set for expDate (and strike if not empty)
        function value = setOption2dVarFor (obj, optionVar, value, expDate, strike, spreadComment, varargin)
            [option2dVar, option2d] = obj.getOption2dVar (optionVar, varargin{:});
            if ~exist('option2dVar', 'var') || isempty(option2dVar) 
                % set zeros or emtpy cells, depending on value
                if ischar(value)
                    obj.setOption2dVar (optionVar, cell (size(option2d,1),1), varargin{:}); % set cell
                else
                    obj.setOption2dVar (optionVar, zeros (size(option2d,1),1), varargin{:}); % set zeros
                end
                [option2dVar, option2d] = obj.getOption2dVar (optionVar, varargin{:});
            end
            rows = ones (size(option2d,1),1);
            % filter expDate
            if ~isempty(expDate) 
                rows = rows & (option2d.expDate == expDate);
            end
            % filter strike if exists
            if exist('strike', 'var') && ~isempty(strike) 
                rows = rows & (option2d.strike == strike);
            end
            % filter comment if exists
            if exist('spreadComment', 'var') && ~isempty(spreadComment) 
                rows = rows & strcmpi(option2d.spreadComment, spreadComment);
            end
            % set value in applying rows
            if iscell(value) 
                [option2dVar{rows}] = deal(value{:});
            elseif ischar(value)
                [option2dVar{rows}] = deal(value);
            else
                option2dVar(rows) = value;
            end
            obj.setOption2dVar (optionVar, option2dVar, varargin{:}); % set zeros
        end
        
        
        %  inputs: 
%       - file with current optionTable, name containing timestamp
%       - file with corresponding price data (current, open, low, high, close), name containing
%       identical timestamp
% 
%       Timestamp is equal to datenum(now) called at time when download was
%       started. This is done in the downloader. The downloader should save
%       the timestamps in a separate file (or workspace variable), from
%       which this function will read (and delete once processed)
% 
%       This function appends the price data to the price data table,
%       together with the time stamp (this is also a column in the table).
% 
%       The new price data is saved in table.under
% 
%       The option table is saved in a container.map, with the value being
%       the option table and the key the datenum timestamp
%
%       This function sets the 'latest' property to the latest page!
%
        function addDownloadedPages (obj, timestampNum)
            if namedConst.downloadVerbose
                fprintf('/a')
            end
            try
                % add option page to datestore 
                obj.option3dDs.Files{numel(obj.option3dDs.Files) + 1} = [namedConst.histFolder obj.symbol '_' num2str(timestampNum) '_' namedConst.optionPageEnd namedConst.pageExtension];
            catch ME
				if namedConst.warnings
                    warning(['Still no option data loaded for ' obj.symbol '. Error: ' ME.message])
				end
            end
            try 
                price1d = table2timetable(readtable ([namedConst.histFolder obj.symbol '_' num2str(timestampNum) '_' namedConst.pricePageEnd namedConst.pageExtension]));
                % set option2d (this doesn't takes care of option3d, but it
                % does take care of spreads)
                option2d = table2timetable(readtable ([namedConst.histFolder obj.symbol '_' num2str(timestampNum) '_' namedConst.optionPageEnd namedConst.pageExtension]));
                option2d = option2d(option2d.expDate > datetime(),:);
                option2d = join(option2d, obj.getPrice2dOptionAdd(price1d));
                obj.setOption2d(option2d);

                % set price1d (this also takes care of price2d
                obj.setPrice1d (price1d);
            catch ME
				if namedConst.warnings
					warning(['Exception setting option2d and price1d for ' obj.symbol '. Error: ' ME.message])
				end
            end
        end
        
        % can be called by other classes to determine current timestamp or
        % just return historic timestamp
        function timestamp = getTimestamp (obj, timestamp)
            price2d = obj.getPrice2d();
            if ~exist('timestamp', 'var') || isempty(timestamp)
				timestamp = max(price2d.Properties.RowTimes);
            elseif ~ismember(timestamp, price2d.Properties.RowTimes) % timestamp does not exist in price2d
                [~,idxMin] = min(abs(price2d.Properties.RowTimes - datetime(timestamp)));
                timestamp = price2d.Properties.RowTimes(idxMin);
            end
            timestamp = datetime(timestamp);
        end
        
        function timestamp = getNonDailyTimestamp (obj, varargin)
            timestamp = obj.getTimestamp (varargin{:});
            dailyTimes = obj.getDailyTimes();
            if ismember(timestamp, dailyTimes)
                nonDailyTimes = setdiff(obj.price2d.Properties.RowTimes, dailyTimes);
                [~,idxMin] = min(abs(nonDailyTimes - datetime(timestamp)));
                if ~isempty(idxMin) % will be empty when option2d is set for first time
                    timestamp = nonDailyTimes(idxMin);
                end
            end
        end        
        
        function spreadTable = getSpreads (obj, varargin)
            % make sure option2d is not empty at init
            option2d = obj.getOption2d(varargin{:});
            % at initialization
            if ~ismember ('putQuantity', option2d.Properties.VariableNames)
                obj.loadSpreadsFromFiles();
            end
            spreadTable = obj.viewOption2d({'basics', 'spreadVars'});
            rows = spreadTable.putQuantity ~= 0 | spreadTable.callQuantity ~= 0;
            spreadTable = spreadTable (rows, :);
        end
        
        function addSpreadVars (obj, varargin)
			option2d = obj.getOption2d(varargin{:});
            obj.setOption2dVar ('spreadComment', cell (size(option2d,1),1), varargin{:}); % set cell
            obj.setOption2dVar ('putQuantity', zeros (size(option2d,1),1), varargin{:}); % set zeros   
            obj.setOption2dVar ('callQuantity', zeros (size(option2d,1),1), varargin{:}); % set zeros 
            obj.setOption2dVar ('paidPrice', zeros (size(option2d,1),1), varargin{:}); % set zeros 
            obj.setOption2dVar ('soldPrice', zeros (size(option2d,1),1), varargin{:}); % set zeros 
        end
        
        function setSpreads (obj, spreadTable, varargin)
            if ~isempty(spreadTable)
                % do row by row
                for i = 1:size(spreadTable, 1)
                    expDate = spreadTable.expDate(i);
                    strike = spreadTable.strike(i);
                    obj.setOption2dVarFor ('putQuantity', spreadTable.putQuantity(i), expDate, strike, [], varargin{:});
                    obj.setOption2dVarFor ('callQuantity', spreadTable.callQuantity(i), expDate, strike, [], varargin{:});
                    obj.setOption2dVarFor ('spreadComment', spreadTable.spreadComment(i), expDate, strike, [], varargin{:});
                    obj.setOption2dVarFor ('paidPrice', spreadTable.paidPrice(i), expDate, strike, [], varargin{:});
                    obj.setOption2dVarFor ('soldPrice', spreadTable.soldPrice(i), expDate, strike, [], varargin{:});
                end
            end
        end
        

      
%       Dividend and earnings are optional and if they are provided they
%       should be saved to their (future) timestamp. 
        function addDivToPrice2d (obj, timestamp, dividend)
            error('To be implemented')
        end
        
        % FIXME implement
        function [dividendYield dividendData] = getDividend (obj)
            dividendYield = 0;
            dividendData = [];
        end
        
        function addEarningsToPrice2d (obj, timestamp, earnings)
            error('To be implemented')
        end
        
    end
    
    methods (Static)
        function returnVar = getVarIfExist (varName, table)
            returnVar = [];
            if ismember (varName, table.Properties.VariableNames) % if exists it is correct
                returnVar = table.(varName);
            end
        end
        
        function price2dNonDaily = getPrice2dOptionAdd (table)
            stockChg = table.last - table.prevClose;
            price2dNonDaily = timetable(table.timestamp, table.last, stockChg, table.volume);
            price2dNonDaily.Properties.VariableNames{'Var1'} = 'stockLast';
            price2dNonDaily.Properties.VariableNames{'Var2'} = 'stockChg';
            price2dNonDaily.Properties.VariableNames{'Var3'} = 'stockVolume';
        end
    end
    
end

