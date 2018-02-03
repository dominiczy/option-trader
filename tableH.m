classdef tableH < priceOptionTimeTable
    % Contains operations that can be performed on an - shaped slice (price2d) of
    % a priceOptionTimeTable
    
    methods
        function obj = tableH (varargin)
            fprintf('Constructing tableH.\n')
            obj = obj@priceOptionTimeTable(varargin{:});
        end
        
        % GETTERS (Setters unchanged from parent)
   
         % get a field from price1d for a specific time (or latest if empty)
        function [price1dVar, price1d] = getPrice1dVar (obj, priceVar, varargin)
            [price1dVar, price1d] = getPrice1dVar@priceOptionTimeTable(obj, priceVar, varargin{:}); % if download var requested just retrieve from superclass
            if isempty(price1dVar) || isnan(price1dVar) % recalc if not exist
                obj.calcHistVolatility(); % recalculate just for the date specified in timestamp.
                [price1dVar, price1d] = getPrice1dVar@priceOptionTimeTable(obj, priceVar, varargin{:});
            end
        end    
            
        
         % get a field from price1d for a specific time (or latest if empty)
        function [price2dVar, price2d] = getPrice2dVar (obj, priceVar, varargin)
            [price2dVar, price2d] = getPrice2dVar@priceOptionTimeTable(obj, priceVar, varargin{:}); % if download var requested just retrieve from superclass
            if isempty(price2dVar) % recalc if not exist
                obj.calcHistVolatility(); % recalculate
                [price2dVar, price2d] = getPrice2dVar@priceOptionTimeTable(obj, priceVar, varargin{:});
            end   
       end
       
	   % varargin is timestamp and nDays
       function endDays = getDailyTimes (obj, varargin)
			if numel(varargin) < 2 % only timestamp (or nothing) provided 
				timestamp = obj.getTimestamp(varargin{:});
			else % nDays provided
				timestamp = obj.getTimestamp(varargin{1});
				nDays = varargin{2};
			end
			
           % shift to all end of days from time table, then select only
           % only one end of day for every day until timestamp
           endDays = unique(dateshift(obj.price2d.Properties.RowTimes(obj.price2d.Properties.RowTimes <= timestamp),'start', 'day')); % sometimes Rowtimes is called Time, other times timestamp!
            % shift to market closing time
           endDays = endDays + hours(16);
           % above is needed to remove right weekend days
           endDays = endDays (~isweekend(endDays));
           % decimate for n days
           if exist('nDays', 'var') && ~isempty(nDays)
               endDays = endDays(nDays:nDays:end);
           end
           % remove future times
           endDays = endDays (datetime(endDays,'TimeZone','America/New_York') < datetime('now','TimeZone','America/New_York'));
       end
       
       % returns price2d with only one row for each (end of the) day
	   % varargin is timestamp and nDays
       function price2dDaily = getPrice2dDaily (obj, varargin)
           endDays = obj.getDailyTimes (varargin{:});
            % get nearest data
           price2dDaily = retime(obj.getPrice2d(), endDays);
           % or instead use:
%            price2dDaily = obj.price2d(endDays,:);

       end
       
        % GETTERS and SETTERS for price2dDaily
		% varargin is timestamp and nDays
        function [price2dDailyVar, price2dDaily] = getPrice2dDailyVar (obj, priceVar, varargin)
            if numel(varargin) < 2 % only timestamp (or nothing) provided 
				timestamp = obj.getTimestamp(varargin{:});
			else % nDays provided
				timestamp = varargin{1};
			end
			% get price2dVar to ensure it's calculated and up to date
			obj.getPrice2dVar (priceVar, timestamp);
            price2dDaily = obj.getPrice2dDaily (varargin{:});
            price2dDailyVar = price2dDaily.(priceVar);
        end
       
	   % varargin is Ndays
	   % no Price2dVar can be set for any timestamp other than last
       function value = setPrice2dDailyVar (obj, priceVar, value, varargin)
           priceVarTT = timetable(obj.getDailyTimes (varargin{:})); % empty timetable with times
           priceVarTT.(priceVar) = value; % add priceVar to timetable
           % remove existing priceVar from price2d to avoid duplication
           if ismember (priceVar, obj.price2d.Properties.VariableNames)
               obj.price2d.(priceVar) = [];
           end
           % sychronize with price2d (investigate whether current or previous day set for non daily times)
           % pricestamp from priceVarTT used to avoid setting price2d
           % timestamp to future: priceVarTT.Properties.RowTimes(end)
           try
               obj.setPrice2d (synchronize(priceVarTT, obj.getPrice2d(), 'union', 'previous')); 
           catch ME
               warning('Synchronising failed. Retrying without using <previous>')
               ME
               obj.setPrice2d (synchronize(priceVarTT, obj.getPrice2d(), 'union')); 
           end
       end
       
        % varargin is nDays (FIXME not supported for ATR)
        function calcHistVolatility (obj, nrDays, varargin)
            fprintf('Executing %s: calcHistVolatility.\n', class(obj))
            if ~exist('nrDays', 'var') || isempty(nrDays)
                nrDays = namedConst.defaultVolNrDays;
            end
            obj.calcSD (nrDays, varargin{:});
            obj.calcATR (nrDays);
        end
        
        % varargin is nDays
        function [SD, SDDaily, SDDailyAbs]  = calcSD (obj, nrDays, varargin)
           dayToDayReturn = obj.calcDayToDayReturn (varargin{:});
           last = obj.getPrice2dDailyVar('last', varargin{:});
           SDDaily = movstd (dayToDayReturn, [nrDays-1 0]);
           SDDailyAbs = SDDaily .* last;
           SD = SDDaily * sqrt(namedConst.tradingDaysPerYear);

		   obj.setPrice2dDailyVar (['SD' num2str(nrDays)], SD, varargin{:});
		   obj.setPrice2dDailyVar (['SDDaily' num2str(nrDays)], SDDaily, varargin{:});
		   obj.setPrice2dDailyVar (['SDDailyAbs' num2str(nrDays)], SDDailyAbs, varargin{:});
        end
        
		% varargin is nDays
        function dayToDayReturn = calcDayToDayReturn (obj, varargin)
            close = obj.getPrice2dDailyVar('adjClose', [], varargin{:});
            prevClose = [close(1); close(1:end-1)]; % select close and previous close
            % set prevClose
            obj.setPrice2dDailyVar ('prevClose', prevClose, varargin{:});
            dayToDayReturn = log(close ./ prevClose);  % calculate day to day return
            % ndays provided
            if numel(varargin) > 0
                nDays = varargin{:};
                obj.setPrice2dDailyVar (['dayReturn' num2str(nDays)], dayToDayReturn, varargin{:});
            else
                obj.setPrice2dDailyVar ('dayToDayReturn', dayToDayReturn, varargin{:});
            end
        end
        
        function [trueRange, relTrueRange] = calcTrueRange (obj)
            close = obj.getPrice2dDailyVar('last');
            prevClose = [close(1); close(1:end-1)]; % select previous close
            low = obj.getPrice2dDailyVar('low'); % FIXME split coefficient should be considered and adj_close used, or not?
            high = obj.getPrice2dDailyVar('high');
            % max of each row
            trueRange = max( [ (high - low), abs(high - prevClose), abs(low - prevClose) ] , [], 2); 
            relTrueRange = trueRange ./ prevClose;
            obj.setPrice2dDailyVar ('trueRange', trueRange);
            obj.setPrice2dDailyVar ('relTrueRange', relTrueRange);
        end
        
        function [ATR, relATR, relATRPerYear] = calcATR (obj, nrDays)
            [trueRange, relTrueRange] = obj.calcTrueRange ();
            ATR = movmean(trueRange, [nrDays-1 0]);
            relATR = movmean(relTrueRange, [nrDays-1 0]);
            relATRPerYear = relATR * sqrt( namedConst.tradingDaysPerYear );
			obj.setPrice2dDailyVar (['ATR' num2str(nrDays)], ATR);
			obj.setPrice2dDailyVar (['relATR' num2str(nrDays)], relATR);
			obj.setPrice2dDailyVar (['relATRPerYear' num2str(nrDays)], relATRPerYear);
        end
        
        % varargin is timestamp and nDays
        function [mean, sd] = returnsHistogram (obj, nrDays, varargin)
            returns = 100*obj.getPrice2dDailyVar('dayToDayReturn', varargin{:});
            if exist('nrDays','var') && ~isempty(nrDays)
                returns = returns(end-nrDays+1:end);
            end
            figure
            histfit(returns);
            pd = fitdist(returns,'Normal');
            mean = pd.mu
            sd = pd.sigma * sqrt(namedConst.tradingDaysPerYear)
        end
        
        % indicators
        % varargin is varargin of indicator 
        % FIXME possible to download indicators from alphavantage etc!
        function vout = getIndicator (obj, ind, timestamp, varargin)
            %     Momentum
            %         cci                  = indicators([hi,lo,cl]      ,'cci'    ,tp_per,md_per,const)
            %         roc                  = indicators(price           ,'roc'    ,period)
            %         rsi                  = indicators(price           ,'rsi'    ,period)
            %         [fpctk,fpctd]        = indicators([hi,lo,cl]      ,'fsto'   ,k,d)
            %         [spctk,spctd]        = indicators([hi,lo,cl]      ,'ssto'   ,k,d)
            %         [fpctk,fpctd,jline]  = indicators([hi,lo,cl]      ,'kdj'    ,k,d)
            %         willr                = indicators([hi,lo,cl]      ,'william',period)
            %         [dn,up,os]           = indicators([hi,lo]         ,'aroon'  ,period)
            %         tsi                  = indicators(cl              ,'tsi'    ,r,s)
            %     Trend
            %         sma                  = indicators(price           ,'sma'    ,period)
            %         ema                  = indicators(price           ,'ema'    ,period)
            %         [macd,signal,macdh]  = indicators(cl              ,'macd'   ,short,long,signal)
            %         [pdi,mdi,adx]        = indicators([hi,lo,cl]      ,'adx'    ,period)
            %         t3                   = indicators(price           ,'t3'     ,period,volfact)
            %     Volume
            %         obv                  = indicators([cl,vo]         ,'obv')
            %         cmf                  = indicators([hi,lo,cl,vo]   ,'cmf'    ,period)
            %         force                = indicators([cl,vo]         ,'force'  ,period)
            %         mfi                  = indicators([hi,lo,cl,vo]   ,'mfi'    ,period)
            %     Volatility
            %         [middle,upper,lower] = indicators(price           ,'boll'   ,period,weight,nstd)
            %         [middle,upper,lower] = indicators([hi,lo,cl]      ,'keltner',emaper,atrmul,atrper)
            %         atr                  = indicators([hi,lo,cl]      ,'atr'    ,period)
            %         vr                   = indicators([hi,lo,cl]      ,'vr'     ,period)
            %         hhll                 = indicators([hi,lo]         ,'hhll'   ,period)
            %     Other
            %         [index,value]        = indicators(price           ,'zigzag' ,moveper)
            %         change               = indicators(price           ,'compare')
            %         [pivot sprt res]     = indicators([dt,op,hi,lo,cl],'pivot'  ,type)
            %         sar                  = indicators([hi,lo]         ,'sar'    ,step,maximum)
            if ~exist('timestamp', 'var')
                timestamp = [];
            end
            hi = obj.getPrice2dDailyVar('high', timestamp);
            lo = obj.getPrice2dDailyVar('low', timestamp);
            vo = obj.getPrice2dDailyVar('volume', timestamp);
            op = obj.getPrice2dDailyVar('open', timestamp);
            dt = floor(datenum(obj.getDailyTimes(timestamp)));
            % FIXME check if adjClose if ok, and if hi/lo should be
            % adjusted
            cl = obj.getPrice2dDailyVar('adjClose', timestamp);
            % input argument categories
            hiLoCl = {'cci', 'fsto', 'ssto', 'kdj', 'william', 'adx', 'keltner', 'atr', 'vr'};
            priceOrCl = {'roc', 'rsi', 'tsi', 'sma', 'ema', 'macd', 't3', 'boll', 'zigzag', 'change'};
            hiLo = {'aroon', 'hhll', 'sar'};
            clVo = {'obv', 'force'};
            hiLoClVo = {'cmf', 'mfi'};
            dtOpHiLoCl = {'pivot'};
            if ismember(ind, hiLoCl)
                vin = [hi, lo, cl];
            elseif ismember(ind, priceOrCl)
                vin = cl;
            elseif ismember(ind, hiLo)
                vin = [hi, lo];
            elseif ismember(ind, clVo)
                vin = [cl, vo];
            elseif ismember(ind, hiLoClVo)
                vin = [hi, lo, cl, vo];
            elseif ismember(ind, dtOpHiLoCl)
                vin = [dt, op, hi, lo, cl];
            end
            vout = indicators(vin,ind,varargin{1:end-1});
        end
    end
    
end

