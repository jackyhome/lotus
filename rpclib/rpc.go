package rpclib

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"reflect"
)

type rpcHandler struct {
	paramReceivers []reflect.Type
	nParams        int

	receiver    reflect.Value
	handlerFunc reflect.Value

	errOut int
	valOut int
}

type RPCServer struct {
	methods map[string]rpcHandler
}

func NewServer() *RPCServer {
	return &RPCServer{
		methods: map[string]rpcHandler{},
	}
}

type param struct {
	data []byte
}

func (p *param) UnmarshalJSON(raw []byte) error {
	p.data = make([]byte, len(raw))
	copy(p.data, raw)
	return nil
}

type request struct {
	Jsonrpc string  `json:"jsonrpc"`
	Id      *int    `json:"id,omitempty"`
	Method  string  `json:"method"`
	Params  []param `json:"params"`
}

type respError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type response struct {
	Jsonrpc string      `json:"jsonrpc"`
	Result  interface{} `json:"result"`
	Id      int         `json:"id"`
	Error   *respError  `json:"error,omitempty"`
}

func (s *RPCServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var req request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(500)
		return
	}

	handler, ok := s.methods[req.Method]
	if !ok {
		w.WriteHeader(500)
		return
	}

	callParams := make([]reflect.Value, 1+handler.nParams)
	callParams[0] = handler.receiver
	for i := 0; i < handler.nParams; i++ {
		rp := reflect.New(handler.paramReceivers[i])
		if err := json.NewDecoder(bytes.NewReader(req.Params[i].data)).Decode(rp.Interface()); err != nil {
			w.WriteHeader(500)
			fmt.Println(err)
			return
		}

		callParams[i+1] = reflect.ValueOf(rp.Elem().Interface())
	}

	callResult := handler.handlerFunc.Call(callParams)
	if req.Id == nil {
		return // notification
	}

	resp := response{
		Jsonrpc: "2.0",
		Id:      *req.Id,
	}

	if handler.errOut != -1 {
		err := callResult[handler.errOut].Interface()
		if err != nil {
			resp.Error = &respError{
				Code:    1,
				Message: err.(error).Error(),
			}
		}
	}
	if handler.valOut != -1 {
		resp.Result = callResult[handler.valOut].Interface()
	}

	json.NewEncoder(os.Stderr).Encode(resp)
}

func (s *RPCServer) Register(r interface{}) {
	val := reflect.ValueOf(r)
	//TODO: expect ptr

	name := val.Type().Elem().Name()

	for i := 0; i < val.NumMethod(); i++ {
		method := val.Type().Method(i)

		fmt.Println(name + "." + method.Name)

		funcType := method.Func.Type()
		ins := funcType.NumIn() - 1
		recvs := make([]reflect.Type, ins)
		for i := 0; i < ins; i++ {
			recvs[i] = method.Type.In(i + 1)
		}

		errOut := -1
		valOut := -1

		switch funcType.NumOut() {
		case 0:
		case 1:
			if funcType.Out(0) == reflect.TypeOf(new(error)).Elem() {
				errOut = 0
			} else {
				valOut = 0
			}
		case 2:
			valOut = 0
			errOut = 1
			if funcType.Out(1) != reflect.TypeOf(new(error)).Elem() {
				panic("expected error as second return value")
			}
		default:
			panic("too many error values")
		}

		s.methods[name+"."+method.Name] = rpcHandler{
			paramReceivers: recvs,
			nParams:        ins,

			handlerFunc: method.Func,
			receiver:    val,

			errOut: errOut,
			valOut: valOut,
		}
	}
}
