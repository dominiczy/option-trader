classdef spreadType
    %UNTITLED3 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Name;
        % conditions
        IVLevel;
        IVToHV;
        IVDirection;
        HVLevel;
        HVDirection;
        UnderlyingDirection;
        IntraMonthSkew;
        TermStructure;
        conditionComments;
        
        % execution
        Setup;
        TradingTime;
        RiskReward;
        Adjustments;
        Exit;
        Comments;
    end
    
    methods
        function obj = spreadType (Name, IVLevel, IVToHV, IVDirection, HVLevel, HVDirection, UnderlyingDirection, IntraMonthSkew, TermStructure, conditionComments, Setup, TradingTime, RiskReward, Adjustments, Exit, Comments)
            obj.Name = Name;
            % conditions
            obj.IVLevel = IVLevel;
            obj.IVToHV = IVToHV;
            obj.IVDirection = IVDirection;
            obj.HVLevel = HVLevel;
            obj.HVDirection= HVDirection;
            obj.UnderlyingDirection = UnderlyingDirection;
            obj.IntraMonthSkew = IntraMonthSkew;
            obj.TermStructure = TermStructure;
            obj.conditionComments = conditionComments;

            % execution
            obj.Setup = Setup;
            obj.TradingTime = TradingTime;
            obj.RiskReward = RiskReward;
            obj.Adjustments = Adjustments;
            obj.Exit = Exit;
            obj.Comments = Comments;
        end
    end
    
end

