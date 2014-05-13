local Compiler = EXPADV.Compiler

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Token Checking
   --- */

function Compiler:HasTokens( )
	return self.PrepToken ~= nil
end

function Compiler:CurrentToken( Type )
	return ( self.Token and ( self.TokenType == Type ) )
end

function Compiler:AcceptToken( Type, Type2, ... )
	if self.PrepToken and ( self.PrepTokenType == Type ) then
		self:NextToken( )
		return true
	elseif Type2 then
		return self:AcceptToken( Type2, ... )
	end
	
	return false
end

function Compiler:CheckToken( Type, Type2, ... )
	if self.PrepToken and ( self.PrepTokenType == Type ) then
		return true
	elseif Type2 then
		return self:CheckToken( Type2, ... )
	end
	
	return false
end

function Compiler:CheckSequence( ... )
	local Sequence = { ... }
	
	for I, Type in pairs( Sequence ) do
		if !self:AcceptToken( Type ) then
			self.TokenPos = self.TokenPos - I
			self:NextToken( )
			return false
		end
	end
	
	self.TokenPos = self.TokenPos - #Sequence
	self:NextToken( )
	
	return true
end

function Compiler:RequireToken( Type, Message, ... )
	if !self:AcceptToken( Type ) then
		self:TokenError( Message, ... )
	end
end

function Compiler:ExcludeToken( Type, Message, ... )
	if self:AcceptToken( Type ) then
		self:TokenError( Message, ... )
	end
end

function Compiler:ExcludeWhiteSpace( Type, ... )
	if !self:HasTokens( ) then 
		self:TokenError( Message, ... )
	end
end

function Compiler:ExcludeVarArg( )
	self:ExcludeToken( "varg", "Invalid use of vararg (...)" )
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Seperators
   --- */
   
function Compiler:AcceptSeperator( )
	if self:AcceptToken( "sep" ) then
		self.LastSeperator = true
		
		while self:AcceptToken( "sep" ) do
			-- Nom all these seperators!
		end
	end

	return self.LastSeperator
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Expression Error
   --- */

function Compiler:ExpressionError( Trace )
	self:ExcludeWhiteSpace( "Further input required at end of code, incomplete expression" )

	self:ExcludeToken( "add", "Arithmetic operator (+) must be preceded by equation or value" )
	self:ExcludeToken( "sub", "Arithmetic operator (-) must be preceded by equation or value" )
	self:ExcludeToken( "mul", "Arithmetic operator (*) must be preceded by equation or value" )
	self:ExcludeToken( "div", "Arithmetic operator (/) must be preceded by equation or value" )
	self:ExcludeToken( "mod", "Arithmetic operator (%) must be preceded by equation or value" )
	self:ExcludeToken( "exp", "Arithmetic operator (^) must be preceded by equation or value" )

	self:ExcludeToken( "ass", "Assignment operator (=) must be preceded by variable" )
	self:ExcludeToken( "aadd", "Assignment operator (+=) must be preceded by variable" )
	self:ExcludeToken( "asub", "Assignment operator (-=) must be preceded by variable" )
	self:ExcludeToken( "amul", "Assignment operator (*=) must be preceded by variable" )
	self:ExcludeToken( "adiv", "Assignment operator (/=) must be preceded by variable" )

	self:ExcludeToken( "and", "Logical operator (&&) must be preceded by equation or value" )
	self:ExcludeToken( "or", "Logical operator (||) must be preceded by equation or value" )

	self:ExcludeToken( "eq", "Comparason operator (==) must be preceded by equation or value" )
	self:ExcludeToken( "neq", "Comparason operator (!=) must be preceded by equation or value" )
	self:ExcludeToken( "gth", "Comparason operator (>=) must be preceded by equation or value" )
	self:ExcludeToken( "lth", "Comparason operator (<=) must be preceded by equation or value" )
	self:ExcludeToken( "geq", "Comparason operator (>) must be preceded by equation or value" )
	self:ExcludeToken( "leq", "Comparason operator (<) must be preceded by equation or value" )

	self:ExcludeToken( "inc", "Increment operator (++) must be preceded by variable" )
	self:ExcludeToken( "dec", "Decrement operator (--) must be preceded by variable" )

	self:ExcludeToken( "rpa", "Right parenthesis ( )) without matching left parenthesis" )
	self:ExcludeToken( "lcb", "Left curly bracket ({) must be part of an table/if/while/for-statement block" )
	self:ExcludeToken( "rcb", "Right curly bracket (}) without matching left curly bracket" )
	self:ExcludeToken( "lsb", "Left square bracket ([) must be preceded by variable" )
	self:ExcludeToken( "rsb", "Right square bracket (]) without matching left square bracket" )

	self:ExcludeToken( "com", "Comma (,) not expected here, missing an argument?" )
	self:ExcludeToken( "prd", "Method operator (.) must not be preceded by white space" )
	self:ExcludeToken( "col", "Tenarry operator (:) must be part of conditional expression (A ? B : C)." )

	self:ExcludeToken( "if", "If keyword (if) must not appear inside an equation" )
	self:ExcludeToken( "eif", "Else-if keyword (elseif) must be part of an if-statement" )
	self:ExcludeToken( "els", "Else keyword (else) must be part of an if-statement" )

	self:ExcludeToken( "swh", "Switch keyword (switch) must not appear inside an equation" )
	self:ExcludeToken( "cse", "Case keyword (case) must be part of an switch-statement" )
	self:ExcludeToken( "dft", "Default keyword (default) must be part of an switch-statement" )

	self:ExcludeToken( "try", "Try keyword (try) must be part of a try-statement" )
	self:ExcludeToken( "cth", "Catch keyword (catch) must be part of an try-statement" )
	self:ExcludeToken( "fnl", "Final keyword (final) must be part of an try-statement" )

	--self:ExcludeToken( "pred", "predictive operator (@) must not appear inside an equation" )

	self:TokenError( "Unexpected symbol found (%s)", self.PrepTokenName )
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Expressions
   --- */

function Compiler:Expression( Trace )
	local _ExprRoot = self.ExpressionRoot
	self.ExpressionRoot = self:GetTokenTrace( Trace )
	
	local Expression = self:Expression_1( Trace )

	if !Expression then
		self:ExpressionError( Trace )
	end

	self.ExpressionRoot = _ExprRoot

	return self:Expression_Postfix( Expression )
end

-- Stage 1: Grouped Equation, In/Dec
function Compiler:Expression_1( Trace )
	if self:AcceptToken( "lpa" ) then
		local Expression = self:Expression_1( Trace )

		self:RequireToken( "rpa", "Right parenthesis ( )) missing, to close grouped equation." )

		return Expression
	end

	return self:Expression_2( Trace )
end

-- Stage 2: Unary operations, sizeof, casting
function Compiler:Expression_2( Trace )

	if self:AcceptToken( "add" ) then
		self:ExcludeWhiteSpace( "Identity operator (+) must not be succeeded by whitespace" )
		return self:Expression_1( Trace )

	elseif self:AcceptToken( "sub" ) then
		self:ExcludeWhiteSpace( "Negation operator (-) must not be succeeded by whitespace" )
		return self:Compile_NEG( Trace, self:Expression_1( Trace ) )
	
	elseif self:AcceptToken( "not" ) then
		self:ExcludeWhiteSpace( "Logical not operator (!) must not be succeeded by whitespace" )
		return self:Compile_NOT( Trace, self:Expression_1( Trace ) )
		
	elseif self:AcceptToken( "len" ) then
		self:ExcludeWhiteSpace( "length operator (#) must not be succeeded by whitespace" )
		return self:Compile_LEN( Trace, self:Expression_1( Trace ) )
	end

	-- TODO: Casting:
	-- local CastCheck = self:ManualPattern( "%(()[a-z][A-Z0-9]+()%)" )

	-- In C-style order of operatorions, Inrement and Decrement should be here.
	
	return self:Expression_3( Trace )
end

-- Stage 3: Multiplication, division, modulo
function Compiler:Expression_3( Trace )
	local Expression = self:Expression_4( Trace )

	while self:CheckToken( "mul", "div", "mod", "exp" ) do
		if self:AcceptToken( "mul" ) then
			Expression = self:Compile_MUL( Trace, Expression, self:Expression_4( Trace ) )
		elseif self:AcceptToken( "div" ) then
			Expression = self:Compile_DIV( Trace, Expression, self:Expression_4( Trace ) )
		elseif self:AcceptToken( "mod" ) then
			Expression = self:Compile_MOD( Trace, Expression, self:Expression_4( Trace ) )
		elseif self:AcceptToken( "exp" ) then
			Expression = self:Compile_EXP( Trace, Expression, self:Expression_4( Trace ) )
		end
	end

	return Expression
end


-- Stage 4: Addition and subtraction
function Compiler:Expression_4( Trace )
	local Expression = self:Expression_5( Trace )

	while self:CheckToken( "add", "sub" ) do
		if self:AcceptToken( "add" ) then
			Expression = self:Compile_ADD( Trace, Expression, self:Expression_5( Trace ) )
		elseif self:AcceptToken( "sub" ) then
			Expression = self:Compile_SUB( Trace, Expression, self:Expression_5( Trace ) )
		end
	end

	return Expression
end

-- Stage 5: Bitwise shift left and right
function Compiler:Expression_5( Trace )
	local Expression = self:Expression_6( Trace )

	while self:CheckToken( "bshl", "bshr" ) do
		if self:AcceptToken( "bshl" ) then
			Expression = self:Compile_BSHL( Trace, Expression, self:Expression_6( Trace ) )
		elseif self:AcceptToken( "bshr" ) then
			Expression = self:Compile_BSHR( Trace, Expression, self:Expression_6( Trace ) )
		end
	end

	return Expression
end

-- Stage 6: Comparisons Greater and Less
function Compiler:Expression_6( Trace )
	local Expression = self:Expression_7( Trace )

	while self:CheckToken( "lth", "leq", "gth", "geq" ) do
		if self:AcceptToken( "lth" ) then
			Expression = self:Compile_LTH( Trace, Expression, self:Expression_7( Trace ) )
		elseif self:AcceptToken( "leq" ) then
			Expression = self:Compile_LEQ( Trace, Expression, self:Expression_7( Trace ) )
		elseif self:AcceptToken( "gth" ) then
			Expression = self:Compile_GTH( Trace, Expression, self:Expression_7( Trace ) )
		elseif self:AcceptToken( "geq" ) then
			Expression = self:Compile_GEQ( Trace, Expression, self:Expression_7( Trace ) )
		end
	end

	return Expression
end

-- Stage 7: Comparisons equal and not equal.
function Compiler:Expression_7( Trace )
	local Expression = self:Expression_8( Trace )

	while self:CheckToken( "eq", "neg" ) do
		if self:AcceptToken( "eq" ) then
			Expression = self:Compile_EQ( Trace, Expression, self:Expression_8( Trace ) )
		elseif self:AcceptToken( "neg" ) then
			Expression = self:Compile_NEG( Trace, Expression, self:Expression_8( Trace ) )
		end
	end

	return Expression
end

-- Stage 8: bitwise and
function Compiler:Expression_8( Trace )
	local Expression = self:Expression_9( Trace )

	while self:AcceptToken( "band" ) do
		Expression = self:Compile_BAND( Trace, Expression, self:Expression_9( Trace ) )
	end

	return Expression
end

-- Stage 9: bitwise exclusive or
function Compiler:Expression_9( Trace )
	local Expression = self:Expression_10( Trace )

	while self:AcceptToken( "bor" ) do
		Expression = self:Compile_BOR( Trace, Expression, self:Expression_10( Trace ) )
	end

	return Expression
end

-- Stage 10: bitwise or
function Compiler:Expression_10( Trace )
	local Expression = self:Expression_11( Trace )

	while self:AcceptToken( "bxor" ) do
		Expression = self:Compile_BXOR( Trace, Expression, self:Expression_11( Trace ) )
	end

	return Expression
end


-- Stage 11: logical and
function Compiler:Expression_11( Trace )
	local Expression = self:Expression_12( Trace )

	while self:AcceptToken( "and" ) do
		Expression = self:Compile_AND( Trace, Expression, self:Expression_12( Trace ) )
	end

	return Expression
end

-- Stage 12: logical or
function Compiler:Expression_12( Trace )
	local Expression = self:Expression_13( Trace )

	while self:AcceptToken( "or" ) do
		Expression = self:Compile_OR( Trace, Expression, self:Expression_13( Trace ) )
	end

	return Expression
end


-- Stage 13: Ternary
function Compiler:Expression_12( Trace )
	local Expression = self:Expression_Value( )

	while self:AcceptToken( "qsm" ) do
		local Expression2 = self:Expression_1( Trace ) -- Ha Ha, Expression 2 :D

		self:RequireToken( "col", "colon (:) expected for tinary operator." ) -- TODO: This error message is shit.

		Expression = self:Compile_TEN( Trace, Expression, Expression2, self:Expression_1( Trace ) )
	end

	return Expression
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Values
   --- */

-- Stage 13: Raw Values:
function Compiler:Expression_Value( Trace )

	if self:AcceptToken( "tre" ) then
		return self:Compile_BOOL( self:GetTokenTrace( Trace ), true )
	elseif self:AcceptToken( "fls" ) then
		return self:Compile_BOOL( self:GetTokenTrace( Trace ), false )
	elseif self:AcceptToken( "num" ) then
		return self:Compile_NUM( self:GetTokenTrace( Trace ), self.TokenData )
	elseif self:AcceptToken( "str" ) then
		return self:Compile_STR( self:GetTokenTrace( Trace ), self.TokenData )
	end

	return self:Expression_Variable( Trace )
end

-- Stage 14: Increment, Decrement and Variables.
function Compiler:Expression_Variable( Trace )
	if self:AcceptToken( "inc" ) then
		self:RequireToken( "var", "Assigment operator (increment), must be preceeded by variable" )
		
		return self:Compile_INC( Trace, false, self.TokenData )
	
	elseif self:AcceptToken( "dec" ) then
		self:RequireToken( "var", "Assigment operator (decrement), must be preceeded by variable" )
		
		return self:Compile_DEC( Trace, false, self.TokenData )
	
	elseif self:AcceptToken( "cng" ) then
		self:RequireToken( "var", "Memory operator (changed), must be preceeded by variable" )
		
		return self:Compile_CHANGED( Trace, self.TokenData )

	elseif self:AcceptToken( "dlt" ) then
		self:RequireToken( "var", "Memory operator (delta), must be preceeded by variable" )
		
		return self:Compile_DELTA( Trace, self.TokenData )
	
	elseif self:AcceptToken( "var" ) then

		local Variable = self.TokenData

		if self:AcceptToken( "inc" ) then
			return self:Compile_INC( Trace, true, Variable )
		elseif self:AcceptToken( "dec" ) then
			return self:Compile_DEC( Trace, true, Variable )
		end

		return self:Compile_VAR( Trace, Variable )
	end
end

-- Stage 15: Indexing, Calling
function Compiler:Expression_Postfix( Trace, Expression )

	while self:CheckToken( "prd", "lsb", "lpa" ) do

		-- Methods
			if self:AcceptToken( "prd" ) then
				local Trace = self:GetTokenTrace( Trace )

				self:RequireToken( "var", "Method operator (.) must be followed by method name" )

				local Method = self.TokenData

				self:RequireToken( "lpa", "Left parenthesis (( ) missing, after method name" )

				local Inputs = { }

				if !self:CheckToken( "rpa" ) then
					
					Inputs[1] = self:Expression( Trace )

					while self:AcceptToken( "com" ) do

						Inputs[#Inputs + 1] = self:Expression( Trace )

					end
				end

				self:RequireToken( "rpa", "Right parenthesis ( )) missing, to close method parameters" )

				Expression = self:Compile_METHOD( Trace, Expression, Method, Inputs )
			end

		-- Members
			if self:AcceptToken( "lsb" ) then
				local Trace = self:GetTokenTrace( Trace )

				local Index = self:Expression( Trace )

				if !self:AcceptToken( "com" ) then
					self:RequireToken( "rsb", "Right square bracket (]) missing, to close indexing operator [Index]" )

					Expression = self:Compile_GET( Trace, Expression, Index )
				
				elseif !self:AcceptToken( "var", "func" ) then
					self:TraceError( Trace, "Right square bracket (]) expected, to close indexing operator [Index]" )
				else
					local Class = self:GetClass( Trace, self.TokenData, false )

					self:RequireToken( "rsb", "Right square bracket (]) missing, to close indexing operator [Index]" )

					Expression = self:Compile_GET( Trace, Expression, Index, Class.Short )
				end

			end

		-- Call

			if self:AcceptToken( "lpa" ) then
				local Trace = self:GetTokenTrace( Trace )

				local Inputs = { }

				if !self:CheckToken( "rpa" ) then
					
					Inputs[1] = self:Expression( Trace )

					while self:AcceptToken( "com" ) do

						Inputs[#Inputs + 1] = self:Expression( Trace )

					end
				end

				self:RequireToken( "rpa", "Right parenthesis ( ), expected to close function perameters" )

				Expression = self:Compile_CALL( Trace, Expression, Inputs )
			end
		end

	return Expression
end

/* --- ----------------------------------------------------------------------------------------------------------------------------------------------
	@: Statments
   --- */

function Compiler:Statement( Trace )
	local _StmtRoot = self.StatmentRoot
	self.StatmentRoot = self:GetTokenTrace( Trace )
	
	local Statement = self:Statement_1( Trace )

	self.StatmentRoot = _StmtRoot

	return Statement
end

function Compiler:Sequence( Trace, ExitToken )
	local Sequence = { }

	while true do

		if !self:HasTokens( ) then
			break
		elseif ExitToken and self:CheckToken( ExitToken ) then
			break
		end

		Sequence[#Sequence + 1] = self:Statement( Trace ) 

		if !self:AcceptSeperator( ) and self.PrepTokenLine == self.TokenLine then
			self:TokenError( "Statements must be separated by semicolon (;) or newline" )
		end

		-- TODO: Prevent code after, Break, Continue and Return
	end

	return self:Compile_SEQ( Trace, Sequence )
end

-- Stage 1: If statments
function Compiler:Statement_1( Trace )
	if self:AcceptToken( "if" ) then
		self:RequireToken( "lpa", "Left parenthesis (( ) missing, to open condition" )

		local Expression = self:Expression( Trace )

		self:RequireToken( "rpa", "Right parenthesis ( )) missing, to close condition" )

		if self:AcceptToken( "lcb" ) then
			self:PushScope( )

			local Sequence = self:Sequence( Trace, "rcb" )

			self:PopScope( )

			self:RequireToken( "rcb", "Right curly bracket (}) missing, to close if statement" )

			return self:Compile_IF( Trace, Expression, Sequence, self:Statement_2( Trace ) )
		end

		self:PushScope( )

		local Statement = self:Statement( Trace )

		self:PopScope( )

		return self:Compile_IF( Trace, Expression, Statement, self:Statement_2( Trace ) )
	end

	return self:Statement_3( Trace )
end

-- Stage 2: elseif, else statments
function Compiler:Statement_2( Trace )
	if self:AcceptToken( "eif" ) then
		self:RequireToken( "lpa", "Left parenthesis (( ) missing, to open condition" )

		local Expression = self:Expression( Trace )

		self:RequireToken( "rpa", "Right parenthesis ( )) missing, to close condition" )

		if self:AcceptToken( "lcb" ) then
			self:PushScope( )

			local Sequence = self:Sequence( Trace, "rcb" )

			self:PopScope( )

			self:RequireToken( "rcb", "Right curly bracket (}) missing, to close elseif statement" )

			return self:Compile_ELSEIF( Trace, Expression, Sequence, self:Statement_2( Trace ) )
		end

		self:PushScope( )

		local Statement = self:Statement( Trace )

		self:PopScope( )

		return self:Compile_ELSEIF( Trace, Expression, Statement, self:Statement_2( Trace ) )

	elseif self:AcceptToken( "els" ) then

		if self:AcceptToken( "lcb" ) then
			self:PushScope( )

			local Sequence = self:Sequence( Trace, "rcb" )

			self:PopScope( )

			self:RequireToken( "rcb", "Right curly bracket (}) missing, to close elseif statement" )

			return self:Compile_ELSE( Trace, Expression, Sequence )
		end

		self:PushScope( )

		local Statement = self:Statement( Trace )

		self:PopScope( )

		return self:Compile_ELSE( Trace, Expression, Statement )

	end
end